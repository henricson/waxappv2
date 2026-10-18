//
//  SharedAppState.swift
//  waxappv2
//
//  What the app hands its widgets through the shared App Group container:
//  the wax lines the user owns, whether they have access, the last place
//  the app looked up and the display preferences. The widget computes its
//  own recommendation from this, so it stays in step with the app without
//  the app having to be running.
//

import Foundation

nonisolated enum AppGroup {
  static let identifier = "group.com.squarewave.waxappv2"

  static var defaults: UserDefaults {
    UserDefaults(suiteName: identifier) ?? .standard
  }
}

/// A place weather can be looked up for.
nonisolated struct SharedPlace: Codable, Sendable, Hashable {
  var latitude: Double
  var longitude: Double
  var name: String
}

nonisolated struct SharedAppState: Codable, Sendable, Equatable {
  var selectedSeriesIDs: Set<String>
  var hiddenProductIDs: Set<String>
  var hasAccess: Bool
  /// The place the app last showed, manual or from GPS.
  var lastPlace: SharedPlace?
  /// Grip or glide, whichever the app was last showing.
  var activeDomain: WaxDomain
  var usesFahrenheit: Bool
  /// The conditions the app last worked out from the weather, so a widget
  /// that can't reach the weather itself still has something true to show.
  var lastConditions: SharedConditions? = nil

  private static let key = "shared.appState.v1"

  /// What a widget sees before the app has ever written anything.
  static let initial = SharedAppState(
    selectedSeriesIDs: WaxCatalog.defaultSeriesIDs,
    hiddenProductIDs: [],
    hasAccess: false,
    lastPlace: nil,
    activeDomain: .grip,
    usesFahrenheit: false
  )

  static func load(from defaults: UserDefaults = AppGroup.defaults) -> SharedAppState? {
    guard let data = defaults.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(SharedAppState.self, from: data)
  }

  /// Writes the state, returning true when it differed from what was stored
  /// — the cue to ask WidgetKit for fresh timelines.
  @discardableResult
  func save(to defaults: UserDefaults = AppGroup.defaults) -> Bool {
    guard Self.load(from: defaults) != self,
      let data = try? JSONEncoder().encode(self)
    else { return false }
    defaults.set(data, forKey: Self.key)
    return true
  }

  /// Products the user has visible in a domain, matching the app's library.
  func visibleProducts(in domain: WaxDomain) -> [WaxProduct] {
    WaxCatalog.all.filter {
      $0.domain == domain
        && selectedSeriesIDs.contains($0.seriesID)
        && !hiddenProductIDs.contains($0.id)
    }
  }
}

/// `WaxConditions` as stored for the widgets, with where and when.
nonisolated struct SharedConditions: Codable, Sendable, Equatable {
  var place: SharedPlace
  var date: Date
  var temperatureC: Int
  var snowType: Int
  var relativeHumidity: Double?
  var recentRainMM: Double
  var recentSnowMM: Double
  var isSnowing: Bool
  var temperatureTrendC: Double?

  init(place: SharedPlace, date: Date, conditions c: WaxConditions) {
    self.place = place
    self.date = date
    temperatureC = c.temperatureC
    snowType = c.snowType.rawValue
    relativeHumidity = c.relativeHumidity
    recentRainMM = c.recentRainMM
    recentSnowMM = c.recentSnowMM
    isSnowing = c.isSnowing
    temperatureTrendC = c.temperatureTrendC
  }

  var conditions: WaxConditions {
    WaxConditions(
      temperatureC: temperatureC, snowType: SnowType(rawValue: snowType) ?? .fineGrained,
      relativeHumidity: relativeHumidity, recentRainMM: recentRainMM, recentSnowMM: recentSnowMM,
      isSnowing: isSnowing, temperatureTrendC: temperatureTrendC)
  }
}

extension WaxDomain {
  /// Deep link that opens the app on this domain.
  nonisolated var appURL: URL {
    URL(string: "getgrip://open?domain=\(rawValue)")!
  }

  nonisolated init?(appURL url: URL) {
    guard url.scheme == "getgrip",
      let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?.first(where: { $0.name == "domain" })?.value
    else { return nil }
    self.init(rawValue: value)
  }
}
