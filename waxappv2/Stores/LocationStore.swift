import Foundation
import CoreLocation
import Combine
import MapKit

@MainActor
final class LocationStore: NSObject, ObservableObject {
    @Published var location: AppLocation? = nil
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorDescription: String?
    
    private let manager = CLLocationManager()
    private var manualLocation: AppLocation? = nil
    
    var isManualOverride: Bool {
        manualLocation != nil
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }
    
    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestLocation() {
        manager.requestLocation()
    }
    
    func setManualLocation(_ loc: AppLocation) {
        self.manualLocation = loc
        self.location = loc
        Task { await updatePlaceName(for: loc) }
    }
    
    func clearManualLocation() {
        self.manualLocation = nil
        // If we have a GPS location cached in manager?
        // We probably just want to request location again.
        requestLocation()
    }
    
    func locationStream() -> AsyncStream<AppLocation?> {
        AsyncStream { continuation in
            continuation.yield(self.location)
            
            let token = self.$location.sink { val in
                continuation.yield(val)
            }
            
            continuation.onTermination = { _ in
                token.cancel()
            }
        }
    }
    
    private func updatePlaceName(for loc: AppLocation) async {
        let clLoc = CLLocation(latitude: loc.lat, longitude: loc.lon)
        if let request = MKReverseGeocodingRequest(location: clLoc) {
            do {
                let mapitems = try await request.mapItems
                if let mapitem = mapitems.first {
                    // Update the location with the place name
                     self.location = AppLocation(
                        lat: loc.lat,
                        lon: loc.lon,
                        placeName: mapitem.name
                     )
                }
            } catch {
                print("Error reverse geocoding: \(error)")
            }
        }
    }
}

extension LocationStore: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        // Only update if manual override is not active
        if manualLocation == nil {
            let appLoc = AppLocation(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude, placeName: nil)
            self.location = appLoc
            
            // Reverse geocode
            Task {
                await updatePlaceName(for: appLoc)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorDescription = error.localizedDescription
    }
}
