import Foundation
import CoreLocation
import Combine
import MapKit

/// Store managing location services and state.
/// Handles authorization, location updates, reverse geocoding, and manual location overrides.
@MainActor
final class LocationStore: NSObject, ObservableObject {
    /// The current location (either GPS or manually set)
    @Published var location: AppLocation? = nil
    
    /// The current authorization status for location services
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    /// Error description if location operations fail
    @Published var errorDescription: String?
    
    private let locationManager: LocationManagerProvider
    private let geocodingService: ReverseGeocodingService
    private var manualLocation: AppLocation? = nil
    
    /// Whether the current location is manually set by the user
    var isManualOverride: Bool {
        manualLocation != nil
    }

    /// Convenience initializer with default dependencies.
    convenience override init() {
        self.init(
            locationManager: CLLocationManagerAdapter(),
            geocodingService: MKReverseGeocodingService()
        )
    }
    
    /// Designated initializer with dependency injection.
    /// - Parameters:
    ///   - locationManager: The location manager provider for location services
    ///   - geocodingService: The service for reverse geocoding operations
    init(
        locationManager: LocationManagerProvider,
        geocodingService: ReverseGeocodingService
    ) {
        self.locationManager = locationManager
        self.geocodingService = geocodingService
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    // MARK: - Public Methods
    
    /// Requests when-in-use authorization for location services.
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    /// Requests a one-time location update.
    func requestLocation() {
        locationManager.requestLocation()
    }
    
    /// Sets a manual location override.
    /// When set, GPS location updates are ignored until cleared.
    /// - Parameter loc: The location to set manually
    func setManualLocation(_ loc: AppLocation) {
        self.manualLocation = loc
        self.location = loc
        Task { await updatePlaceName(for: loc) }
    }
    
    /// Clears the manual location override.
    /// Resumes using GPS location updates.
    func clearManualLocation() {
        self.manualLocation = nil
        requestLocation()
    }
    
    /// Creates an async stream of location updates.
    /// The stream yields the current location immediately, then yields subsequent updates.
    /// - Returns: An async stream of optional locations
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
    
    // MARK: - Private Methods
    
    /// Updates the place name for a location using reverse geocoding.
    /// - Parameter loc: The location to reverse geocode
    private func updatePlaceName(for loc: AppLocation) async {
        if let placeName = await geocodingService.placeName(for: loc.lat, longitude: loc.lon) {
            self.location = AppLocation(
                lat: loc.lat,
                lon: loc.lon,
                placeName: placeName
            )
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationStore: CLLocationManagerDelegate {
    /// Called when the authorization status changes.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// Called when new location data is available.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        
        // Only update if manual override is not active
        if manualLocation == nil {
            let appLoc = AppLocation(
                lat: loc.coordinate.latitude,
                lon: loc.coordinate.longitude,
                placeName: nil
            )
            self.location = appLoc
            
            // Reverse geocode to get place name
            Task {
                await updatePlaceName(for: appLoc)
            }
        }
    }
    
    /// Called when the location manager encounters an error.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorDescription = error.localizedDescription
    }
}
