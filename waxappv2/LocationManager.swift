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

    // Configuration: set to true if you want to automatically perform a one-shot fetch
    // immediately after the user grants permission.
    var autoFetchAfterGrant: Bool = true

    private let manager: CLLocationManager
    private var pendingOneShotRequest: Bool = false

    override init() {
        self.manager = CLLocationManager()
        self.authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100

        // Only request authorization if needed; no continuous updates.
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

    // MARK: - Optional continuous updates (not used by default)

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    // MARK: - Settings

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {
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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        lastLocation = latest
        errorDescription = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // locationUnknown is transient with requestLocation(); retry can be initiated by user
        errorDescription = error.localizedDescription
    }
}
