import CoreLocation
import Foundation

struct AppLocation: Equatable {
  let lat: Double
  let lon: Double
  var placeName: String?

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: lat, longitude: lon)
  }

  var clLocation: CLLocation {
    CLLocation(latitude: lat, longitude: lon)
  }
}
