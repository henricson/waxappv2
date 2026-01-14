//
//  LocationStore.swift
//  waxappv2
//
//  Store managing location services and reverse geocoding.
//

import Foundation
import CoreLocation
import Combine
import MapKit

enum LocationStatus {
    case searching
    case fault_searching
    case active
    case manual_override
}

/// Store that manages location updates, authorization, and reverse geocoding.
/// Uses LocationManagerProvider for location services and ReverseGeocodingService for address lookup.
@MainActor
final class LocationStore: NSObject, ObservableObject {
    /// The current location, or nil if not available
    @Published var location: AppLocation? = nil
    
    @Published var locationStatus : LocationStatus = .searching
    
    /// The current location authorization status
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    /// Error description if location services fail
    @Published var errorDescription: String?
    
    /// Location manager provider for testability
    private let manager: LocationManagerProvider
    
    /// Reverse geocoding service for place name lookup
    private let geocodingService: ReverseGeocodingService
    
    /// Manually set location that overrides GPS location
    // private var manualLocation: AppLocation? = nil

    /// Convenience initializer that supplies default dependencies on the main actor to avoid actor-isolation warnings.
    @MainActor
    convenience override init() {
        self.init(
            manager: CLLocationManagerAdapter(),
            geocodingService: MKReverseGeocodingService()
        )
    }

    /// Initializes the store with custom dependencies.
    /// - Parameters:
    ///   - manager: The location manager provider (defaults to CLLocationManagerAdapter)
    ///   - geocodingService: The reverse geocoding service (defaults to MKReverseGeocodingService)
    init(
        manager: LocationManagerProvider,
        geocodingService: ReverseGeocodingService
    ) {
        self.manager = manager
        self.geocodingService = geocodingService
        super.init()
        
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }
    
    /// Requests authorization for location services.
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    /// Requests a one-time location update.
    func requestLocation() {
        self.locationStatus = .searching
        manager.requestLocation()
    }
    
    /// Sets a manual location, overriding GPS location.
    /// - Parameter loc: The location to set
    func setManualLocation(_ loc: AppLocation) {
        //self.manualLocation = loc
        self.location = loc
        self.locationStatus = .manual_override
        Task { await updatePlaceName(for: loc) }
    }
    
    /// Clears the manual location override and requests a new GPS location.
    func clearManualLocation() {
        self.location = nil
        self.locationStatus = .searching
        // Request location again to get fresh GPS coordinates
        requestLocation()
    }
    
    /// Creates an async stream of location updates.
    /// The stream yields the current location immediately, then yields subsequent updates.
    /// - Returns: An async stream that yields location updates
    func locationStream() -> AsyncStream<AppLocation?> {
        AsyncStream { continuation in
            // Yield current location immediately
            continuation.yield(self.location)
            
            // Subscribe to location updates
            let token = self.$location.sink { val in
                continuation.yield(val)
            }
            
            // Clean up subscription when stream terminates
            continuation.onTermination = { _ in
                token.cancel()
            }
        }
    }
    
    /// Updates the place name for a location using reverse geocoding.
    /// - Parameter loc: The location to geocode
    private func updatePlaceName(for loc: AppLocation) async {
        guard let placeName = await geocodingService.placeName(for: loc.lat, longitude: loc.lon) else {
            return
        }
        
        // Update the location with the place name
        self.location = AppLocation(
            lat: loc.lat,
            lon: loc.lon,
            placeName: placeName
        )
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationStore: CLLocationManagerDelegate {
    /// Called when location authorization status changes.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    /// Called when new location data is available.
    /// - Parameters:
    ///   - manager: The location manager
    ///   - locations: Array of location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        // Only update if manual override is not active
        if locationStatus != .manual_override {
            let appLoc = AppLocation(
                lat: loc.coordinate.latitude,
                lon: loc.coordinate.longitude,
                placeName: nil
            )
            self.location = appLoc
            self.locationStatus = .active
            
            // Reverse geocode to get place name
            Task {
                await updatePlaceName(for: appLoc)
            }
        }
    }
    
    /// Called when location manager encounters an error.
    /// - Parameters:
    ///   - manager: The location manager
    ///   - error: The error that occurred
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorDescription = error.localizedDescription
    }
}

