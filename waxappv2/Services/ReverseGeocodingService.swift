//
//  ReverseGeocodingService.swift
//  waxappv2
//
//  Service for reverse geocoding operations.
//

import Foundation
import MapKit
import CoreLocation

/// Protocol for reverse geocoding functionality.
/// Abstracts geocoding operations to enable testing.
protocol ReverseGeocodingService {
    /// Converts coordinates to a place name.
    /// - Parameters:
    ///   - latitude: The latitude coordinate
    ///   - longitude: The longitude coordinate
    /// - Returns: The place name, or nil if geocoding fails
    func placeName(for latitude: Double, longitude: Double) async -> String?
}

/// MapKit-based implementation of reverse geocoding service.
/// Uses MKReverseGeocodingRequest for address lookup.
final class MKReverseGeocodingService: ReverseGeocodingService {
    func placeName(for latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }
        
        do {
            let mapItems = try await request.mapItems
            return mapItems.first?.name
        } catch {
            print("Error reverse geocoding: \(error)")
            return nil
        }
    }
}
