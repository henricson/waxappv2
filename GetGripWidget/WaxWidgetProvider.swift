//
//  WaxWidgetProvider.swift
//  GetGripWidget
//
//  Builds a widget entry the same way the app builds its main screen: the
//  user's own wax library from the App Group, ten days of hourly weather,
//  the snow classifier, and the shared recommender.
//

import CoreLocation
import MapKit
import WidgetKit

// MARK: - Entry

struct DomainPick: Sendable {
  let domain: WaxDomain
  let top: WaxRecommendation?
  let alternatives: [WaxProduct]
  let preparation: WaxProduct?
}

struct WaxEntry: TimelineEntry {
  enum State: Sendable, Equatable {
    case ready
    /// No subscription or lifetime unlock.
    case locked
    /// "Fixed place" chosen but no place picked yet.
    case needsPlace
    /// Neither the widget nor the app has a location to use.
    case needsLocation
    case weatherUnavailable
  }

  let date: Date
  let state: State
  let choice: WidgetWaxChoice
  /// The app's last-used domain, used by "Automatic" when there is room for one.
  let preferredDomain: WaxDomain
  let placeName: String?
  let temperatureC: Int?
  let snowType: SnowType?
  let usesFahrenheit: Bool
  let grip: DomainPick?
  let glide: DomainPick?

  func pick(for domain: WaxDomain) -> DomainPick? {
    domain == .grip ? grip : glide
  }

  /// The domains this entry should show, given room for one or for two.
  func domains(roomForTwo: Bool) -> [WaxDomain] {
    switch choice {
    case .grip: return [.grip]
    case .glide: return [.glide]
    case .both: return [.grip, .glide]
    case .automatic: return roomForTwo ? [.grip, .glide] : [preferredDomain]
    }
  }

  var temperatureText: String? {
    temperatureC.map {
      TemperatureDisplay(unit: usesFahrenheit ? .fahrenheit : .celsius).string(fromCelsius: $0)
    }
  }
}

// MARK: - Provider

struct WaxWidgetProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> WaxEntry {
    .sample(choice: .automatic)
  }

  func snapshot(for configuration: WaxWidgetIntent, in context: Context) async -> WaxEntry {
    if context.isPreview { return .sample(choice: configuration.waxChoice) }
    return await makeEntry(for: configuration)
  }

  func timeline(for configuration: WaxWidgetIntent, in context: Context) async -> Timeline<WaxEntry> {
    let entry = await makeEntry(for: configuration)
    // Snow changes over hours, not minutes. Retry sooner after a failure.
    let minutes = entry.state == .ready ? 60 : 20
    let next = Date().addingTimeInterval(TimeInterval(minutes * 60))
    return Timeline(entries: [entry], policy: .after(next))
  }

  // MARK: Building an entry

  private func makeEntry(for configuration: WaxWidgetIntent) async -> WaxEntry {
    let shared = SharedAppState.load() ?? .initial

    func entry(
      _ state: WaxEntry.State, place: String? = nil, conditions: WaxConditions? = nil
    ) -> WaxEntry {
      WaxEntry(
        date: Date(), state: state, choice: configuration.waxChoice,
        preferredDomain: shared.activeDomain, placeName: place,
        temperatureC: conditions?.temperatureC, snowType: conditions?.snowType,
        usesFahrenheit: shared.usesFahrenheit,
        grip: conditions.map { pick(.grip, shared: shared, conditions: $0) },
        glide: conditions.map { pick(.glide, shared: shared, conditions: $0) })
    }

    guard shared.hasAccess else { return entry(.locked) }

    let place: SharedPlace
    switch configuration.locationMode {
    case .fixed:
      guard let chosen = configuration.place else { return entry(.needsPlace) }
      place = chosen.sharedPlace
    case .current:
      guard let current = await currentPlace(fallback: shared.lastPlace) else {
        return entry(.needsLocation)
      }
      place = current
    }

    let location = CLLocation(latitude: place.latitude, longitude: place.longitude)
    let now = Date()
    let interval = DateInterval(start: now.addingTimeInterval(-10 * 24 * 3600), end: now)
    guard
      let points = try? await WeatherKitWeatherProviderFactory().makeProvider()
        .data(for: location, in: interval, granularity: .hourly),
      let conditions = WeatherDigest(points: points, now: now).conditions
    else { return entry(.weatherUnavailable, place: place.name) }

    return entry(.ready, place: place.name, conditions: conditions)
  }

  private func pick(_ domain: WaxDomain, shared: SharedAppState, conditions: WaxConditions) -> DomainPick {
    let products = shared.visibleProducts(in: domain)
    let ranked = WaxRecommender.rank(products: products, conditions: conditions)
    return DomainPick(
      domain: domain,
      top: ranked.first,
      alternatives: ranked.dropFirst().prefix(3).map(\.product),
      preparation: WaxRecommender.preparation(from: products, for: conditions)?.product)
  }

  /// The device's location when the user has allowed widgets to use it,
  /// otherwise the place the app last showed.
  private func currentPlace(fallback: SharedPlace?) async -> SharedPlace? {
    let manager = CLLocationManager()
    guard manager.isAuthorizedForWidgetUpdates, let location = manager.location else {
      return fallback
    }

    // Reuse the app's name for the spot when the widget is standing on it.
    if let fallback,
      location.distance(from: CLLocation(latitude: fallback.latitude, longitude: fallback.longitude)) < 3000
    {
      return SharedPlace(
        latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
        name: fallback.name)
    }

    let name = await placeName(for: location) ?? String(localized: "Widget_CurrentLocation")
    return SharedPlace(
      latitude: location.coordinate.latitude, longitude: location.coordinate.longitude, name: name)
  }

  private func placeName(for location: CLLocation) async -> String? {
    guard let request = MKReverseGeocodingRequest(location: location),
      let item = try? await request.mapItems.first
    else { return nil }
    return item.address?.shortAddress ?? item.name
  }
}

// MARK: - Sample

extension WaxEntry {
  /// A plausible winter morning, for the gallery and placeholders.
  static func sample(choice: WidgetWaxChoice) -> WaxEntry {
    let conditions = WaxConditions(temperatureC: -6, snowType: .fineGrained)
    func pick(_ domain: WaxDomain) -> DomainPick {
      let products = SharedAppState.initial.visibleProducts(in: domain)
      let ranked = WaxRecommender.rank(products: products, conditions: conditions)
      return DomainPick(
        domain: domain, top: ranked.first,
        alternatives: ranked.dropFirst().prefix(3).map(\.product), preparation: nil)
    }
    return WaxEntry(
      date: Date(), state: .ready, choice: choice, preferredDomain: .grip,
      placeName: "Holmenkollen", temperatureC: -6, snowType: .fineGrained,
      usesFahrenheit: false, grip: pick(.grip), glide: pick(.glide))
  }
}
