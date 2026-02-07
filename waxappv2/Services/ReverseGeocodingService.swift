//
//  ReverseGeocodingService.swift
//  waxappv2
//
//  Service for reverse geocoding operations.
//

import CoreLocation
import Foundation
import MapKit

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

/// CoreLocation-based implementation of reverse geocoding service.
/// Uses CLGeocoder for address lookup.
final class MKReverseGeocodingService: ReverseGeocodingService {
  private let geocoder = CLGeocoder()

  func placeName(for latitude: Double, longitude: Double) async -> String? {
    let location = CLLocation(latitude: latitude, longitude: longitude)

    do {
      let placemarks = try await geocoder.reverseGeocodeLocation(location)

      // Try to get the most relevant name from the placemark
      if let placemark = placemarks.first {
        // Prefer name, then locality, then administrative area
        return placemark.name
          ?? placemark.locality
          ?? placemark.administrativeArea
      }

      return nil
    } catch {
      print("Error reverse geocoding: \(error)")
      return nil
    }
  }
}
