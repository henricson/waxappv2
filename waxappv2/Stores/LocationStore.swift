//
//  LocationStore.swift
//  waxappv2
//

import Foundation
import CoreLocation
import Observation

enum LocationStatus: Equatable {
    case idle
    case searching
    case active
    case manual_override
    case denied          // User denied location permission
}

@MainActor
@Observable
final class LocationStore: NSObject {
    
    // MARK: - Public State
    
    private(set) var location: AppLocation?
    var locationStatus: LocationStatus = .idle
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    /// Controls whether automatic location requests are allowed.
    /// Set to true after onboarding and paywall are dismissed.
    var isLocationRequestEnabled: Bool = false
    
    // MARK: - Private
    
    private let locationManager: CLLocationManager
    private let geocoder: CLGeocoder
    
    // MARK: - Authorization Helpers
    private var isAuthorized: Bool {
        #if os(macOS)
        return authorizationStatus == .authorized
        #else
        return authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
        #endif
    }

    private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        #if os(macOS)
        return status == .authorized
        #else
        return status == .authorizedWhenInUse || status == .authorizedAlways
        #endif
    }
    
    // MARK: - Coordinate Validation
    
    /// Validates that coordinates are within valid ranges
    /// - Parameters:
    ///   - lat: Latitude (-90 to 90)
    ///   - lon: Longitude (-180 to 180)
    /// - Returns: true if coordinates are valid
    private func isValidCoordinate(lat: Double, lon: Double) -> Bool {
        return lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
    }
    
    // MARK: - Init
    
    override init() {
        self.locationManager = CLLocationManager()
        self.geocoder = CLGeocoder()
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        guard isAuthorized else {
            return
        }
        
        // Stop any in-flight updates first so that startUpdatingLocation()
        // is guaranteed to produce a fresh location callback.
        locationManager.stopUpdatingLocation()
        locationStatus = .searching
        locationManager.startUpdatingLocation()
    }
    
    func setManualLocation(_ location: AppLocation) {
        // Validate coordinates before setting
        guard isValidCoordinate(lat: location.lat, lon: location.lon) else {
            #if DEBUG
            print("⚠️ Invalid coordinates: \(location.lat), \(location.lon)")
            #endif
            return
        }
        self.location = location
        locationStatus = .manual_override
    }
    
    func setManualLocation(lat: Double, lon: Double) async {
        // Validate coordinates
        guard isValidCoordinate(lat: lat, lon: lon) else {
            #if DEBUG
            print("⚠️ Invalid coordinates: \(lat), \(lon)")
            #endif
            return
        }
        
        locationStatus = .searching
        
        #if DEBUG
        print("📍 Manual location set: \(lat), \(lon)")
        #endif
        let placeName = await reverseGeocode(lat: lat, lon: lon)
        #if DEBUG
        print("📍 Reverse geocoded place name: \(placeName ?? "nil")")
        #endif
        
        location = AppLocation(lat: lat, lon: lon, placeName: placeName)
        locationStatus = .manual_override
    }
    
    func setManualLocation(coordinate: CLLocationCoordinate2D) async {
        await setManualLocation(lat: coordinate.latitude, lon: coordinate.longitude)
    }
    
    func clearManualLocation() {
        // Clear location and reset status for both manual and device locations
        // This allows the location button to force a fresh location request
        location = nil
        locationStatus = .idle
        
        // After clearing, request a fresh device location
        requestLocation()
    }
    
    // MARK: - Private Methods
    
    private func reverseGeocode(lat: Double, lon: Double) async -> String? {
        let clLocation = CLLocation(latitude: lat, longitude: lon)
        
        do {
            #if DEBUG
            print("🔍 Starting reverse geocode for: \(lat), \(lon)")
            #endif
            let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
            #if DEBUG
            print("🔍 Received \(placemarks.count) placemark(s)")
            #endif
            
            if let placemark = placemarks.first {
                let formattedName = formatPlaceName(from: placemark)
                #if DEBUG
                print("✅ Formatted place name: \(formattedName)")
                #endif
                return formattedName
            } else {
                #if DEBUG
                print("⚠️ No placemarks returned")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Geocoding failed: \(error.localizedDescription)")
            if let clError = error as? CLError {
                print("❌ CLError code: \(clError.code.rawValue)")
            }
            #endif
        }
        
        return nil
    }
    
    private func formatPlaceName(from placemark: CLPlacemark) -> String {
        if let locality = placemark.locality {
            if let area = placemark.subLocality ?? placemark.administrativeArea {
                return "\(locality), \(area)"
            }
            return locality
        }
        
        if let name = placemark.name {
            return name
        }
        
        if let area = placemark.administrativeArea {
            return area
        }
        
        return "Unknown Location"
    }
    
    private func handleLocationUpdate(_ clLocation: CLLocation) async {
        locationManager.stopUpdatingLocation()
        
        let lat = clLocation.coordinate.latitude
        let lon = clLocation.coordinate.longitude
        
        #if DEBUG
        print("📍 Location updated: \(lat), \(lon)")
        #endif
        
        let placeName = await reverseGeocode(lat: lat, lon: lon)
        
        // Reset to nil first so that the @Observable system always sees a
        // change — even if the new coordinates are identical to the previous
        // ones (e.g. the user hasn't moved). Without this, WeatherStore's
        // withObservationTracking won't fire and fetchWeather() is skipped.
        location = nil
        location = AppLocation(lat: lat, lon: lon, placeName: placeName)
        locationStatus = .active
        
        #if DEBUG
        print("📍 Location set: \(placeName ?? "Unknown")")
        #endif
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationStore: CLLocationManagerDelegate {
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let clLocation = locations.last else { return }
        
        Task { @MainActor in
            await self.handleLocationUpdate(clLocation)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Only handle permanent failures, not transient ones
        // CLError.locationUnknown is temporary - location services will keep trying
        if let clError = error as? CLError {
            switch clError.code {
            case .locationUnknown:
                // Temporary error - location services are still trying
                #if DEBUG
                print("📍 Location temporarily unavailable, still searching...")
                #endif
                return
            case .denied:
                // User denied permission
                Task { @MainActor in
                    self.locationStatus = .denied
                }
            default:
                #if DEBUG
                print("❌ Location error: \(error.localizedDescription)")
                #endif
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        Task { @MainActor in
            self.authorizationStatus = status
            
            // Update status if denied
            if status == .denied || status == .restricted {
                self.locationStatus = .denied
            }
            
            // Only auto-request location if enabled (after onboarding/paywall dismissed)
            if self.isAuthorized(status) && self.isLocationRequestEnabled {
                if self.locationStatus != .manual_override {
                    self.requestLocation()
                }
            }
        }
    }
}
