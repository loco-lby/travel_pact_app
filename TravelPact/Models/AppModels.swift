// This file helps consolidate model imports for better IDE resolution
// All types should be accessible within the same module, but this helps IDE indexing

import Foundation
import SwiftUI
import CoreLocation
import Combine

// Type aliases to help IDE resolution
// These reference the actual implementations in their respective files

// From TravelPactApp.swift
typealias AuthManager = AuthenticationManager

// Note: The actual types are defined in:
// - AuthenticationManager in TravelPactApp.swift
// - LocationPrivacyManager in Services/LocationPrivacyManager.swift
// - ConnectionsManager in Services/ConnectionsManager.swift
// - Connection in Services/ConnectionsManager.swift
// - WaypointsManager in Services/WaypointsManager.swift
// - Waypoint in Services/WaypointsManager.swift
// - MediaService in Services/MediaService.swift
// - ContactLocationManager in Services/ContactLocationManager.swift
// - ContactSyncService in Services/ContactSyncService.swift
// - TravelPactContact in Models/ContactTypes.swift
// - CoordinateWrapper in Models/CoordinateWrapper.swift
// - UserProfile in Services/SupabaseClient.swift
// - LocationData in Services/SupabaseClient.swift