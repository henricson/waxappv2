//
//  DemoMode.swift
//  waxappv2
//
//  Deterministic state for App Store screenshots and UI tests.
//
//  Enabled by launching with `-GGDemoMode YES`, optionally with
//  `-GGDemoPlace "Holmenkollen"`, `-GGDemoTemperature -6`,
//  `-GGDemoSnowType 2` and `-GGDemoDomain grip|glide`.
//
//  Nothing in here runs unless the flag is set, so a shipping launch is
//  unaffected.
//

import CoreLocation
import Foundation

enum DemoMode {

  static var isEnabled: Bool {
    UserDefaults.standard.bool(forKey: "GGDemoMode")
  }

  // MARK: - Overrides

  static var placeName: String {
    UserDefaults.standard.string(forKey: "GGDemoPlace") ?? "Holmenkollen, Oslo"
  }

  static var coordinate: CLLocationCoordinate2D {
    let defaults = UserDefaults.standard
    let latitude =
      defaults.object(forKey: "GGDemoLatitude") as? Double ?? 59.9639
    let longitude =
      defaults.object(forKey: "GGDemoLongitude") as? Double ?? 10.6680
    return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }

  /// Read as a string: NSUserDefaults' argument domain treats a value
  /// beginning with "-" as the next key, and shell quotes don't survive into
  /// argv, so negative temperatures are passed with a leading space
  /// (`-GGDemoTemperature " -8"`) and trimmed here.
  static var temperature: Int {
    let defaults = UserDefaults.standard
    if let text = defaults.string(forKey: "GGDemoTemperature"),
      let value = Int(text.trimmingCharacters(in: .whitespaces))
    {
      return value
    }
    return defaults.object(forKey: "GGDemoTemperature") as? Int ?? -6
  }

  static var snowType: SnowType {
    // `integer(forKey:)` also parses the string a launch argument arrives as.
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: "GGDemoSnowType") != nil else { return .fineGrained }
    return SnowType(rawValue: defaults.integer(forKey: "GGDemoSnowType")) ?? .fineGrained
  }

  static var domain: WaxDomain {
    let raw = UserDefaults.standard.string(forKey: "GGDemoDomain")
    return raw.flatMap(WaxDomain.init(rawValue:)) ?? .grip
  }

  /// Skip onboarding so the main screen can be captured directly.
  static var skipsOnboarding: Bool {
    !UserDefaults.standard.bool(forKey: "GGDemoShowOnboarding")
  }

  /// Which onboarding page to open on, when onboarding is being captured.
  static var onboardingPage: Int {
    UserDefaults.standard.integer(forKey: "GGDemoOnboardingPage")
  }

  /// Turns on "Explain recommendations" for the capture.
  static var showsAdvanced: Bool {
    UserDefaults.standard.bool(forKey: "GGDemoAdvanced")
  }

  /// A screen to open over the main view: `library` or `map`.
  static var screen: String? {
    UserDefaults.standard.string(forKey: "GGDemoScreen")
  }

  /// Series to show, as `brand.code` ids. Empty means the regional kit.
  static var seriesIDs: [String] {
    UserDefaults.standard.string(forKey: "GGDemoSeries")?
      .split(separator: ",")
      .map { String($0).trimmingCharacters(in: .whitespaces) }
      ?? []
  }

  // MARK: - Synthetic weather

  /// Ten days of plausible hourly weather ending now, shaped so the
  /// classifier lands on `snowType`.
  static func weatherHistory(now: Date = Date()) -> [WeatherDataPointModel] {
    let hours = 240
    let target = snowType
    let current = Double(temperature)

    return (0..<hours).reversed().map { hoursAgo -> WeatherDataPointModel in
      let end = now.addingTimeInterval(-Double(hoursAgo) * 3600)
      let start = end.addingTimeInterval(-3600)

      // A gentle diurnal swing around the target temperature.
      let phase = Double(hoursAgo) / 24.0 * 2 * .pi
      var temperature = current + 2.0 * sin(phase)
      var snow = 0.0
      var rain = 0.0

      switch target {
      case .newFallen, .moistNewFallen:
        // Snow falling over the last few hours.
        if hoursAgo < 8 { snow = 1.6 }
      case .fineGrained, .moistFineGrained:
        // Snow two days ago, dry since.
        if (44...50).contains(hoursAgo) { snow = 2.4 }
      case .oldGrained:
        // Last snowfall over a week ago.
        if (200...210).contains(hoursAgo) { snow = 3.0 }
      case .transformedMoistFine:
        if (60...70).contains(hoursAgo) { temperature = 2.5 }
        if (180...190).contains(hoursAgo) { snow = 2.0 }
      case .frozenCorn:
        // A thaw, then a long refreeze.
        if (30...48).contains(hoursAgo) { temperature = 3.0 }
        if (150...160).contains(hoursAgo) { snow = 4.0 }
      case .wetCorn, .veryWetCorn:
        temperature = max(temperature, 1.0)
        if hoursAgo < 20 { rain = 0.4 }
      }

      return WeatherDataPointModel(
        start: start,
        end: end,
        averageAmountOfSnow: snow,
        averageAmountOfRain: rain,
        averageTemperature: hoursAgo == 0 ? current : temperature,
        relativeHumidity: 0.82,
        windSpeed: 2.4,
        snowDepthCM: 48
      )
    }
  }
}

// MARK: - Provider

/// Serves `DemoMode.weatherHistory()` instead of hitting the network.
struct DemoWeatherProviderFactory: WeatherProviderFactory {
  func makeProvider() -> WeatherProvider { DemoWeatherProvider() }
}

struct DemoWeatherProvider: WeatherProvider {
  var sourceName: String { "Demo" }

  func data(
    for location: CLLocation,
    in interval: DateInterval,
    granularity: WeatherGranularity
  ) async throws -> [WeatherDataPointModel] {
    DemoMode.weatherHistory(now: interval.end)
  }
}
