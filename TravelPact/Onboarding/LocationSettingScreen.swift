import SwiftUI
import MapKit
import CoreLocation
import SceneKit

struct LocationSettingScreen: View {
    @Binding var currentStep: OnboardingStep
    @StateObject private var locationPrivacyManager = LocationPrivacyManager.shared
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var showingLocationPicker = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var addressString = ""
    
    var body: some View {
        ZStack {
            AnimatedGradientBackground()
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: {
                        withAnimation {
                            currentStep = .profileCreation
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            currentStep = .photoAnalysis  // Skip to photo analysis
                        }
                    }) {
                        Text("Skip")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            Text("Set Your Location")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("Your location is private - you control when to share")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 20)
                        
                        ZStack {
                            Mini3DGlobeView(selectedLocation: $selectedLocation)
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 24))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.3),
                                                    Color.white.opacity(0.1)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                            
                            if selectedLocation == nil {
                                VStack(spacing: 8) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text("Tap to set location")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding()
                                .background(
                                    Capsule()
                                        .fill(Color.black.opacity(0.4))
                                        .background(
                                            Capsule()
                                                .fill(.ultraThinMaterial)
                                        )
                                )
                            }
                        }
                        .padding(.horizontal, 32)
                        .onTapGesture {
                            showingLocationPicker = true
                        }
                        
                        VStack(spacing: 20) {
                            if let location = selectedLocation {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        Text(addressString.isEmpty ? "Location selected" : addressString)
                                            .font(.system(size: 16, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.9))
                                        
                                        Spacer()
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.1))
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(.ultraThinMaterial)
                                            )
                                    )
                                }
                                .padding(.horizontal, 32)
                            }
                            
                            VStack(spacing: 16) {
                                Button(action: useCurrentLocation) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 16))
                                        Text("Use Current Location")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(LiquidGlassButtonStyle(isPrimary: false))
                                .padding(.horizontal, 32)
                                
                                Button(action: saveLocation) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                        } else {
                                            Text("Continue")
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(LiquidGlassButtonStyle(isPrimary: true))
                                .padding(.horizontal, 32)
                                .disabled(selectedLocation == nil || isLoading)
                            }
                            
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 32)
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text("Your exact location is never shared publicly")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationSearchView { coordinate, name in
                selectedLocation = coordinate
                addressString = name
            }
        }
    }
    
    private func useCurrentLocation() {
        if let location = locationPrivacyManager.actualLocation {
            selectedLocation = location.coordinate
            
            locationPrivacyManager.reverseGeocode(location: location) { name in
                addressString = name
            }
        }
    }
    
    private func reverseGeocode(location: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            if let placemark = placemarks?.first {
                var components: [String] = []
                if let city = placemark.locality {
                    components.append(city)
                }
                if let country = placemark.country {
                    components.append(country)
                }
                addressString = components.joined(separator: ", ")
            }
        }
    }
    
    private func saveLocation() {
        guard let location = selectedLocation else { return }
        
        isLoading = true
        errorMessage = ""
        
        // Set the known location using LocationPrivacyManager
        locationPrivacyManager.updateKnownLocation(
            coordinate: location,
            name: addressString.isEmpty ? "Location Set" : addressString
        )
        
        // Navigate to next screen after a short delay to allow sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                currentStep = .photoAnalysis  // Skip to photo analysis
                isLoading = false
            }
        }
    }
}

struct Mini3DGlobeView: UIViewRepresentable {
    @Binding var selectedLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
        sceneView.backgroundColor = .clear
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        
        let scene = SCNScene()
        sceneView.scene = scene
        
        let globe = SCNSphere(radius: 2.0)
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "earth_texture") ?? UIColor.systemBlue.withAlphaComponent(0.8)
        material.specular.contents = UIColor.white
        material.emission.contents = UIColor.blue.withAlphaComponent(0.1)
        globe.materials = [material]
        
        let globeNode = SCNNode(geometry: globe)
        globeNode.position = SCNVector3(0, 0, 0)
        
        let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 30)
        let repeatAction = SCNAction.repeatForever(rotateAction)
        globeNode.runAction(repeatAction)
        
        scene.rootNode.addChildNode(globeNode)
        
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 6)
        scene.rootNode.addChildNode(cameraNode)
        
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light?.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        if let location = selectedLocation {
            if let pinNode = uiView.scene?.rootNode.childNode(withName: "pin", recursively: true) {
                pinNode.removeFromParentNode()
            }
            
            let pin = SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.3)
            pin.firstMaterial?.diffuse.contents = UIColor.systemRed
            let pinNode = SCNNode(geometry: pin)
            pinNode.name = "pin"
            
            let lat = location.latitude * .pi / 180
            let lon = location.longitude * .pi / 180
            let radius: Float = 2.15
            
            let x = radius * cos(Float(lat)) * cos(Float(lon))
            let y = radius * sin(Float(lat))
            let z = radius * cos(Float(lat)) * sin(Float(lon))
            
            pinNode.position = SCNVector3(x, y, z)
            pinNode.eulerAngles = SCNVector3(Float(lat) - .pi/2, 0, Float(lon))
            
            uiView.scene?.rootNode.addChildNode(pinNode)
        }
    }
}

