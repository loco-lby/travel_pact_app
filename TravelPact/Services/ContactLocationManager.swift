import Foundation
import CoreData
import CoreLocation

class ContactLocationManager: ObservableObject {
    static let shared = ContactLocationManager()
    
    @Published var contactLocations: [String: ContactLocationData] = [:]
    @Published var favoriteContacts: Set<String> = []
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ContactLocation")
        container.loadPersistentStores { _, error in
            if let error = error {
                print("❌ Core Data failed to load: \(error)")
            }
        }
        return container
    }()
    
    private init() {
        loadAllContactLocations()
        loadFavorites()
    }
    
    // MARK: - Public Methods
    
    func assignLocation(to contactIdentifier: String, location: ContactLocationData) {
        // Save to Core Data
        let context = persistentContainer.viewContext
        
        // Check if location already exists
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "ContactLocation")
        fetchRequest.predicate = NSPredicate(format: "contactIdentifier == %@", contactIdentifier)
        
        do {
            let results = try context.fetch(fetchRequest)
            
            let contactLocation: NSManagedObject
            if let existing = results.first {
                contactLocation = existing
            } else {
                contactLocation = NSEntityDescription.insertNewObject(forEntityName: "ContactLocation", into: context)
                contactLocation.setValue(contactIdentifier, forKey: "contactIdentifier")
            }
            
            // Update values
            contactLocation.setValue(location.locationName, forKey: "locationName")
            contactLocation.setValue(location.latitude, forKey: "latitude")
            contactLocation.setValue(location.longitude, forKey: "longitude")
            contactLocation.setValue(location.address, forKey: "address")
            contactLocation.setValue(location.city, forKey: "city")
            contactLocation.setValue(location.country, forKey: "country")
            contactLocation.setValue(Date(), forKey: "lastUpdated")
            
            try context.save()
            
            // Update in-memory cache
            contactLocations[contactIdentifier] = location
            
            print("✅ Location assigned to contact: \(location.locationName)")
            
        } catch {
            print("❌ Failed to save contact location: \(error)")
        }
    }
    
    func getLocation(for contactIdentifier: String) -> ContactLocationData? {
        return contactLocations[contactIdentifier]
    }
    
    func removeLocation(for contactIdentifier: String) {
        let context = persistentContainer.viewContext
        
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "ContactLocation")
        fetchRequest.predicate = NSPredicate(format: "contactIdentifier == %@", contactIdentifier)
        
        do {
            let results = try context.fetch(fetchRequest)
            for object in results {
                context.delete(object)
            }
            try context.save()
            
            contactLocations.removeValue(forKey: contactIdentifier)
            
        } catch {
            print("❌ Failed to remove contact location: \(error)")
        }
    }
    
    // MARK: - Favorite Management
    
    func toggleFavorite(for contactIdentifier: String) {
        if favoriteContacts.contains(contactIdentifier) {
            favoriteContacts.remove(contactIdentifier)
        } else {
            favoriteContacts.insert(contactIdentifier)
        }
        saveFavorites()
    }
    
    func isFavorite(_ contactIdentifier: String) -> Bool {
        return favoriteContacts.contains(contactIdentifier)
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteContacts), forKey: "favoriteContacts")
    }
    
    private func loadFavorites() {
        if let saved = UserDefaults.standard.array(forKey: "favoriteContacts") as? [String] {
            favoriteContacts = Set(saved)
        }
    }
    
    func getContactGroups(for contacts: [TravelPactContact]) -> [ContactLocationGroup] {
        // Group contacts by their location coordinates
        var locationGroups: [String: ContactLocationGroup] = [:]
        
        for contact in contacts {
            guard let contactId = contact.contactIdentifier,
                  let locationData = contactLocations[contactId] else {
                continue
            }
            
            // Create a key for grouping (rounded coordinates to avoid floating point precision issues)
            let roundedLat = round(locationData.latitude * 1000) / 1000
            let roundedLng = round(locationData.longitude * 1000) / 1000
            let locationKey = "\(roundedLat),\(roundedLng)"
            
            if var existingGroup = locationGroups[locationKey] {
                existingGroup.contacts.append(contact)
                locationGroups[locationKey] = existingGroup
            } else {
                locationGroups[locationKey] = ContactLocationGroup(
                    locationData: locationData,
                    contacts: [contact]
                )
            }
        }
        
        return Array(locationGroups.values)
    }
    
    // MARK: - Private Methods
    
    private func loadAllContactLocations() {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "ContactLocation")
        
        do {
            let results = try context.fetch(fetchRequest)
            
            for result in results {
                guard let identifier = result.value(forKey: "contactIdentifier") as? String,
                      let locationName = result.value(forKey: "locationName") as? String,
                      let latitude = result.value(forKey: "latitude") as? Double,
                      let longitude = result.value(forKey: "longitude") as? Double else {
                    continue
                }
                
                let location = ContactLocationData(
                    locationName: locationName,
                    latitude: latitude,
                    longitude: longitude,
                    address: result.value(forKey: "address") as? String,
                    city: result.value(forKey: "city") as? String,
                    country: result.value(forKey: "country") as? String
                )
                
                contactLocations[identifier] = location
            }
            
            print("📍 Loaded \(contactLocations.count) contact locations from Core Data")
            
        } catch {
            print("❌ Failed to load contact locations: \(error)")
        }
    }

    // MARK: - Cache Management

    func clearCache() {
        // Clear in-memory cache
        contactLocations.removeAll()

        // Clear Core Data
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "ContactLocation")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)

        do {
            try context.execute(deleteRequest)
            try context.save()
            print("✅ Contact location cache cleared")
        } catch {
            print("❌ Failed to clear contact location cache: \(error)")
        }
    }
}

// MARK: - Data Model

struct ContactLocationData: Codable {
    let locationName: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let city: String?
    let country: String?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ContactLocationGroup {
    let locationData: ContactLocationData
    var contacts: [TravelPactContact]
    
    var count: Int {
        contacts.count
    }
    
    var displayName: String {
        if count == 1 {
            return contacts.first?.displayName ?? "Contact"
        } else {
            return "\(count) contacts"
        }
    }
}