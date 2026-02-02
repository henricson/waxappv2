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
    case fault_searching
}

@MainActor
@Observable
final class LocationStore: NSObject {
    
    // MARK: - Public State
    
    private(set) var location: AppLocation?
    var locationStatus: LocationStatus = .idle
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
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
        self.location = location
        locationStatus = .manual_override
    }
    
    func setManualLocation(lat: Double, lon: Double) async {
        locationStatus = .searching
        
        print("📍 Manual location set: \(lat), \(lon)")
        let placeName = await reverseGeocode(lat: lat, lon: lon)
        print("📍 Reverse geocoded place name: \(placeName ?? "nil")")
        
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
            print("🔍 Starting reverse geocode for: \(lat), \(lon)")
            let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
            print("🔍 Received \(placemarks.count) placemark(s)")
            
            if let placemark = placemarks.first {
                let formattedName = formatPlaceName(from: placemark)
                print("✅ Formatted place name: \(formattedName)")
                return formattedName
            } else {
                print("⚠️ No placemarks returned")
            }
        } catch {
            print("❌ Geocoding failed: \(error.localizedDescription)")
            if let clError = error as? CLError {
                print("❌ CLError code: \(clError.code.rawValue)")
            }
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
        
        print("📍 Location updated: \(lat), \(lon)")
        
        let placeName = await reverseGeocode(lat: lat, lon: lon)
        
        // Reset to nil first so that the @Observable system always sees a
        // change — even if the new coordinates are identical to the previous
        // ones (e.g. the user hasn't moved). Without this, WeatherStore's
        // withObservationTracking won't fire and fetchWeather() is skipped.
        location = nil
        location = AppLocation(lat: lat, lon: lon, placeName: placeName)
        locationStatus = .active
        
        print("📍 Location set: \(placeName ?? "Unknown")")
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
        print("❌ Location error: \(error.localizedDescription)")
        
        Task { @MainActor in
            if self.locationStatus != .manual_override {
                self.locationStatus = .fault_searching
            }
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        Task { @MainActor in
            self.authorizationStatus = status
            
            if self.isAuthorized(status) {
                // Request location immediately when authorized, unless user has manually overridden
                if self.locationStatus != .manual_override {
                    self.requestLocation()
                }
            }
        }
    }
}
