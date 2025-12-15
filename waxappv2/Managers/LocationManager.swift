//
//  LocationManager.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import Foundation
import CoreLocation
import Combine
import UIKit

@MainActor
final class LocationManager: NSObject, ObservableObject {
    // Published properties for the UI
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?
    @Published var errorDescription: String?

    // New: Human-readable place name (e.g., city, locality, administrative area)
    @Published var placeName: String?

    // Manual override (user-picked location)
    @Published var manualLocation: CLLocation?
    @Published private(set) var isManualOverride: Bool = false

    // A single effective location the app should use:
    // - manualLocation if set
    // - otherwise lastLocation from CLLocationManager
    var effectiveLocation: CLLocation? {
        manualLocation ?? lastLocation
    }

    // Configuration: set to true if you want to automatically perform a one-shot fetch
    // immediately after the user grants permission.
    var autoFetchAfterGrant: Bool = true

    private let manager: CLLocationManager
    private let geocoder = CLGeocoder()

    // To avoid excessive reverse geocoding, only geocode if we moved more than this distance
    private let geocodeDistanceThreshold: CLLocationDistance = 200 // meters
    private var lastGeocodedLocation: CLLocation?

    private var pendingOneShotRequest: Bool = false

    override init() {
        self.manager = CLLocationManager()
        self.authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100

        // Only request authorization if needed.
        requestAuthorizationIfNeeded()
    }

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorDescription = "Location permission is denied or restricted. Enable it in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Manual override

    /// Set a user-selected location as the manual override.
    func setManualLocation(_ location: CLLocation) {
        manualLocation = location
        isManualOverride = true
        errorDescription = nil
        // Update name for manual location
        Task { await reverseGeocodeIfNeeded(for: location, force: true) }
    }

    /// Clear the manual override and fall back to automatic location.
    func clearManualOverride() {
        manualLocation = nil
        isManualOverride = false
        // When clearing, try to resolve name for the last known device location
        if let loc = lastLocation {
            Task { await reverseGeocodeIfNeeded(for: loc, force: true) }
        }
    }

    /// Fully reset location state so UI shows "Fetch location".
    func resetToNoLocation() {
        // Stop any geocoding
        if geocoder.isGeocoding {
            geocoder.cancelGeocode()
        }
        // Prevent any pending auto-fetch flow
        pendingOneShotRequest = false
        // Clear all location-related state
        manualLocation = nil
        isManualOverride = false
        lastLocation = nil
        lastGeocodedLocation = nil
        placeName = nil
        errorDescription = nil
    }

    // MARK: - One-shot location fetch

    /// Call this to fetch the user's location once.
    /// - Parameters:
    ///   - autoRequestPermission: If true and status is .notDetermined, this will trigger permission prompt.
    func fetchLocationOnce(autoRequestPermission: Bool = true) {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            if autoRequestPermission {
                pendingOneShotRequest = true
                manager.requestWhenInUseAuthorization()
            } else {
                errorDescription = "Location permission not determined."
            }
        case .denied, .restricted:
            errorDescription = "Location permission is denied or restricted. Enable it in Settings."
        @unknown default:
            break
        }
    }

    // MARK: - Reverse geocoding

    /// Public helper to refresh the human-readable place name for the current effective location.
    func refreshPlaceName() {
        guard let loc = effectiveLocation else { return }
        Task { await reverseGeocodeIfNeeded(for: loc, force: true) }
    }

    /// Reverse geocode the given location if it moved sufficiently or when forced.
    private func shouldGeocode(for location: CLLocation, force: Bool) -> Bool {
        if force || lastGeocodedLocation == nil { return true }
        guard let prev = lastGeocodedLocation else { return true }
        return location.distance(from: prev) > geocodeDistanceThreshold
    }

    private func updatePlaceName(from placemark: CLPlacemark?) {
        guard let pm = placemark else {
            placeName = nil
            return
        }

        // Prefer locality (city/town), then subAdministrativeArea, then administrativeArea, then country
        let components: [String?] = [
            pm.locality,
            pm.subLocality,
            pm.administrativeArea,
            pm.country
        ]
        let name = components.compactMap { $0 }.first
        placeName = name
    }

    private func cancelGeocodeIfNeeded() {
        if geocoder.isGeocoding {
            geocoder.cancelGeocode()
        }
    }

    private func reverseGeocode(loc: CLLocation) async {
        // CLGeocoder has no async API; bridge with continuation
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, error in
                guard let self else {
                    continuation.resume()
                    return
                }
                if let error = error as NSError?, error.code == CLError.Code.geocodeFoundNoResult.rawValue {
                    // No result is not critical; clear name
                    self.placeName = nil
                } else if let error = error {
                    // Keep previous name, but log error
                    self.errorDescription = error.localizedDescription
                } else {
                    self.updatePlaceName(from: placemarks?.first)
                    self.lastGeocodedLocation = loc
                }
                continuation.resume()
            }
        }
    }

    private func reverseGeocodeIfNeeded(for location: CLLocation, force: Bool = false) async {
        guard shouldGeocode(for: location, force: force) else { return }
        cancelGeocodeIfNeeded()
        await reverseGeocode(loc: location)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
    // Here authorization status changed
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if pendingOneShotRequest && autoFetchAfterGrant {
                pendingOneShotRequest = false
                manager.requestLocation()
            }
        case .denied, .restricted:
            errorDescription = "Location permission is denied or restricted. Enable it in Settings."
            pendingOneShotRequest = false
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    // Here comes a new location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        lastLocation = latest
        errorDescription = nil

        // Resolve place name for the new location
        Task { await reverseGeocodeIfNeeded(for: latest) }
    }

    // Here it failed
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // locationUnknown is transient with requestLocation(); retry can be initiated by user
        errorDescription = error.localizedDescription
    }
}
