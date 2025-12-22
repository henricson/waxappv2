//
//  LocationManager.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import Foundation
import CoreLocation
import Combine
import MapKit

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?
    @Published var manualLocation: CLLocation?
    @Published var placeName: String?
    @Published var errorDescription: String?
    
    private let manager = CLLocationManager()
    
    var effectiveLocation: CLLocation? {
        manualLocation ?? lastLocation
    }
    
    var isManualOverride: Bool {
        manualLocation != nil
    }
    
    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestAuthorizationIfNeeded() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }
    
    func fetchLocationOnce() {
        requestAuthorizationIfNeeded()
        manager.requestLocation()
    }
    
    func setManualLocation(_ location: CLLocation) {
        manualLocation = location
        updatePlaceName(for: location)
    }
    
    func clearManualOverride() {
        manualLocation = nil
        if let last = lastLocation {
            updatePlaceName(for: last)
        } else {
            placeName = nil
        }
    }
    
    func resetToNoLocation() {
        lastLocation = nil
        manualLocation = nil
        placeName = nil
        errorDescription = nil
    }
    
    private func updatePlaceName(for location: CLLocation) {
        Task {
            if let request = MKReverseGeocodingRequest(location: location) {
                let mapitems = try? await request.mapItems
                if let mapitem = mapitems?.first {
                    self.placeName = mapitem.name
                }
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        if manualLocation == nil {
            updatePlaceName(for: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorDescription = error.localizedDescription
    }
}
