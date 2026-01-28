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
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            return
        }
        
        locationStatus = .searching
        locationManager.requestLocation()
    }
    
    func setManualLocation(_ location: AppLocation) {
        self.location = location
        locationStatus = .manual_override
    }
    
    func setManualLocation(lat: Double, lon: Double) async {
        locationStatus = .searching
        
        let placeName = await reverseGeocode(lat: lat, lon: lon)
        
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
    }
    
    // MARK: - Private Methods
    
    private func reverseGeocode(lat: Double, lon: Double) async -> String? {
        let clLocation = CLLocation(latitude: lat, longitude: lon)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
            
            if let placemark = placemarks.first {
                return formatPlaceName(from: placemark)
            }
        } catch {
            print("❌ Geocoding failed: \(error.localizedDescription)")
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
        let lat = clLocation.coordinate.latitude
        let lon = clLocation.coordinate.longitude
        let placeName = await reverseGeocode(lat: lat, lon: lon)
        
        location = AppLocation(lat: lat, lon: lon, placeName: placeName)
        locationStatus = .active
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
            
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                if self.locationStatus == .idle {
                    self.requestLocation()
                }
            }
        }
    }
}
