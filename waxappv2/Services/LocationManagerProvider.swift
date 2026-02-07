//
//  LocationManagerProvider.swift
//  waxappv2
//
//  Protocol abstraction for CLLocationManager to enable testing.
//

import CoreLocation
import Foundation

/// Protocol that abstracts CLLocationManager functionality for testability.
/// Allows mocking of location services in unit tests.
protocol LocationManagerProvider: AnyObject {
  /// The delegate for location events
  var delegate: CLLocationManagerDelegate? { get set }

  /// The desired accuracy for location updates
  var desiredAccuracy: CLLocationAccuracy { get set }

  /// The current authorization status for location services
  var authorizationStatus: CLAuthorizationStatus { get }

  /// Requests when-in-use authorization for location services
  func requestWhenInUseAuthorization()

  /// Requests a one-time location update
  func requestLocation()
}

/// Adapter that makes CLLocationManager conform to LocationManagerProvider.
/// Wraps the standard CLLocationManager to provide the protocol interface.
final class CLLocationManagerAdapter: NSObject, LocationManagerProvider {
  private let locationManager: CLLocationManager

  var delegate: CLLocationManagerDelegate? {
    get { locationManager.delegate }
    set { locationManager.delegate = newValue }
  }

  var desiredAccuracy: CLLocationAccuracy {
    get { locationManager.desiredAccuracy }
    set { locationManager.desiredAccuracy = newValue }
  }

  var authorizationStatus: CLAuthorizationStatus {
    locationManager.authorizationStatus
  }

  override init() {
    self.locationManager = CLLocationManager()
    super.init()
  }

  func requestWhenInUseAuthorization() {
    locationManager.requestWhenInUseAuthorization()
  }

  func requestLocation() {
    locationManager.requestLocation()
  }
}
