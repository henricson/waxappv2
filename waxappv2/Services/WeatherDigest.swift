//
//  WeatherDigest.swift
//  waxappv2
//
//  The handful of signals the recommender needs, read off a run of hourly
//  weather. Shared by `WeatherStore` and the widgets so both reason about
//  the same snowpack in the same way.
//

import Foundation

nonisolated struct WeatherDigest: Sendable {
  /// Oldest first.
  let points: [WeatherDataPointModel]
  let now: Date

  init(points: [WeatherDataPointModel], now: Date = Date()) {
    self.points = points.sorted { $0.start < $1.start }
    self.now = now
  }

  /// The data point closest to now, which may be slightly in the past.
  var latestPoint: WeatherDataPointModel? {
    points
      .filter { $0.start <= now.addingTimeInterval(3600) }
      .max(by: { $0.start < $1.start })
      ?? points.last
  }

  var currentTemperature: Double? { latestPoint?.averageTemperature }

  var currentHumidity: Double? { latestPoint?.relativeHumidity }

  var currentSnowDepthCM: Double? { points.compactMap(\.snowDepthCM).last }

  /// Liquid precipitation over the last 24 h, mm.
  var recentRainMM: Double { sum(\.averageAmountOfRain, overLastHours: 24) }

  /// Snowfall over the last 24 h, mm.
  var recentSnowMM: Double { sum(\.averageAmountOfSnow, overLastHours: 24) }

  /// True when meaningful snow fell in the most recent hour on record.
  var isSnowingNow: Bool { (latestPoint?.averageAmountOfSnow ?? 0) >= 0.3 }

  /// Air temperature change over the last 6 h, °C.
  var temperatureTrendC: Double? {
    guard let latest = points.last else { return nil }
    let sixHoursAgo = now.addingTimeInterval(-6 * 3600)
    guard let earlier = points.last(where: { $0.start <= sixHoursAgo }) ?? points.first,
      earlier.start < latest.start
    else { return nil }
    return latest.averageTemperature - earlier.averageTemperature
  }

  func snowType(at temperature: Double) -> SnowType {
    SnowTypeClassifier.classify(currentTemperature: temperature, weatherDataPoints: points)
  }

  /// Conditions for the recommender, straight from the weather.
  var conditions: WaxConditions? {
    guard let temperature = currentTemperature else { return nil }
    return WaxConditions(
      temperatureC: Int(temperature.rounded()),
      snowType: snowType(at: temperature),
      relativeHumidity: currentHumidity,
      recentRainMM: recentRainMM,
      recentSnowMM: recentSnowMM,
      isSnowing: isSnowingNow,
      temperatureTrendC: temperatureTrendC
    )
  }

  private func sum(_ keyPath: KeyPath<WeatherDataPointModel, Double>, overLastHours hours: Int) -> Double {
    let cutoff = now.addingTimeInterval(-Double(hours) * 3600)
    return points
      .filter { $0.end > cutoff && $0.start <= now }
      .reduce(0) { $0 + $1[keyPath: keyPath] }
  }
}
