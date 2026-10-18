//
//  WaxWidgetConfiguration.swift
//  GetGripWidget
//
//  The widget's settings: where to read the weather, and which waxes to
//  show. A fixed place is searched for by name, so a widget can follow the
//  trail you ski at the weekend while the app follows you.
//

import AppIntents
import CoreLocation
import MapKit
import WidgetKit

// MARK: - Options

enum WidgetLocationMode: String, AppEnum {
  case current
  case fixed

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Location"

  static let caseDisplayRepresentations: [WidgetLocationMode: DisplayRepresentation] = [
    .current: "Current Location",
    .fixed: "Fixed Place",
  ]
}

/// Which recommendations the widget shows.
///
/// "Automatic" fits the content to the size: one wax where there is only
/// room for one, both grip and glide where there is room for two.
enum WidgetWaxChoice: String, AppEnum {
  case automatic
  case grip
  case glide
  case both

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Wax"

  static let caseDisplayRepresentations: [WidgetWaxChoice: DisplayRepresentation] = [
    .automatic: "Automatic",
    .grip: "Grip Wax",
    .glide: "Glide Wax",
    .both: "Grip and Glide",
  ]
}

// MARK: - Place

struct PlaceEntity: AppEntity {
  let latitude: Double
  let longitude: Double
  let name: String
  /// Municipality and region, to tell apart places that share a name.
  let detail: String?

  /// Encodes the whole place, so it can be rebuilt without a lookup. It
  /// must round-trip exactly: AppIntents matches resolved entities to saved
  /// widget settings by this string.
  var id: String {
    ([String(latitude), String(longitude), name] + (detail.map { [$0] } ?? [])).joined(separator: "|")
  }

  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Place"
  static let defaultQuery = PlaceQuery()

  var displayRepresentation: DisplayRepresentation {
    if let detail, !detail.isEmpty {
      return DisplayRepresentation(title: "\(name)", subtitle: "\(detail)")
    }
    return DisplayRepresentation(title: "\(name)")
  }

  init(latitude: Double, longitude: Double, name: String, detail: String? = nil) {
    self.latitude = latitude
    self.longitude = longitude
    self.name = name
    self.detail = detail
  }

  init?(id: String) {
    let parts = id.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
    guard parts.count >= 3, let lat = Double(parts[0]), let lon = Double(parts[1]) else { return nil }
    self.init(
      latitude: lat, longitude: lon, name: parts[2],
      detail: parts.count > 3 && !parts[3].isEmpty ? parts[3] : nil)
  }

  var sharedPlace: SharedPlace {
    SharedPlace(latitude: latitude, longitude: longitude, name: name)
  }

  var location: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}

struct PlaceQuery: EntityStringQuery {
  func entities(for identifiers: [PlaceEntity.ID]) async throws -> [PlaceEntity] {
    identifiers.compactMap(PlaceEntity.init(id:))
  }

  /// Searches places by name, the way Maps does.
  func entities(matching string: String) async throws -> [PlaceEntity] {
    let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return [] }

    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query
    request.resultTypes = [.address, .pointOfInterest]

    let response = try await MKLocalSearch(request: request).start()

    // Search often returns the same spot several times (the village, its
    // postcode, a lodge in it). Keep one result per kilometre.
    var places: [PlaceEntity] = []
    for item in response.mapItems {
      let coordinate = item.location.coordinate
      let name = item.name ?? query
      let detail = item.addressRepresentations?.cityWithContext ?? item.address?.shortAddress
      let place = PlaceEntity(
        latitude: coordinate.latitude, longitude: coordinate.longitude,
        name: name, detail: detail == name ? nil : detail)
      guard !places.contains(where: { $0.location.distance(from: place.location) < 1000 }) else { continue }
      places.append(place)
      if places.count == 10 { break }
    }
    return places
  }

  /// Offers the place the app last showed, so the common case is one tap.
  func suggestedEntities() async throws -> [PlaceEntity] {
    guard let place = SharedAppState.load()?.lastPlace else { return [] }
    return [PlaceEntity(latitude: place.latitude, longitude: place.longitude, name: place.name)]
  }
}

// MARK: - Intent

struct WaxWidgetIntent: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Wax of the Day"
  static let description = IntentDescription("Shows the wax that suits the snow right now.")

  @Parameter(title: "Location", default: .current)
  var locationMode: WidgetLocationMode

  @Parameter(title: "Place")
  var place: PlaceEntity?

  @Parameter(title: "Show", default: .automatic)
  var waxChoice: WidgetWaxChoice

  static var parameterSummary: some ParameterSummary {
    When(\.$locationMode, .equalTo, .fixed) {
      Summary("Wax at \(\.$place)") {
        \.$locationMode
        \.$place
        \.$waxChoice
      }
    } otherwise: {
      Summary("Wax at my location") {
        \.$locationMode
        \.$waxChoice
      }
    }
  }

  init() {}

  init(locationMode: WidgetLocationMode, place: PlaceEntity? = nil, waxChoice: WidgetWaxChoice) {
    self.locationMode = locationMode
    self.place = place
    self.waxChoice = waxChoice
  }
}
