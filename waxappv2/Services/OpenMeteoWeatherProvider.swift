//
//  OpenMeteoWeatherProvider.swift
//  waxappv2
//
//  Secondary weather source.
//
//  Open-Meteo is free for non-commercial use, needs no API key, and reports
//  two signals WeatherKit does not expose for past hours: lying snow depth and
//  hourly relative humidity. Both materially improve snow classification, so
//  it runs alongside WeatherKit rather than replacing it.
//
//  https://open-meteo.com/en/docs
//

import CoreLocation
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.squarewave.waxappv2", category: "OpenMeteo")

public struct OpenMeteoWeatherProviderFactory: WeatherProviderFactory {
  public init() {}
  public func makeProvider() -> WeatherProvider { OpenMeteoWeatherProvider() }
}

public struct OpenMeteoWeatherProvider: WeatherProvider {

  public enum ProviderError: Error, LocalizedError {
    case badURL
    case badResponse(Int)
    case emptyPayload

    public var errorDescription: String? {
      switch self {
      case .badURL: return "Could not build the Open-Meteo request."
      case .badResponse(let code): return "Open-Meteo returned HTTP \(code)."
      case .emptyPayload: return "Open-Meteo returned no hourly data."
      }
    }
  }

  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public var sourceName: String { "Open-Meteo" }

  // MARK: - Wire format

  private struct Response: Decodable {
    let hourly: Hourly

    struct Hourly: Decodable {
      let time: [Int]
      let temperature2m: [Double?]
      let relativeHumidity2m: [Double?]?
      let rain: [Double?]?
      let snowfall: [Double?]?
      let snowDepth: [Double?]?
      let windSpeed10m: [Double?]?

      enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case relativeHumidity2m = "relative_humidity_2m"
        case rain
        case snowfall
        case snowDepth = "snow_depth"
        case windSpeed10m = "wind_speed_10m"
      }
    }
  }

  // MARK: - Fetch

  public func data(
    for location: CLLocation,
    in interval: DateInterval,
    granularity: WeatherGranularity
  ) async throws -> [WeatherDataPointModel] {
    // Open-Meteo serves recent history and forecast from one endpoint using
    // `past_days`, which is exactly the 10-day window the classifier wants.
    let days = Calendar.current.dateComponents(
      [.day], from: interval.start, to: interval.end
    ).day ?? 10
    let pastDays = max(1, min(92, days))

    var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
    components?.queryItems = [
      URLQueryItem(name: "latitude", value: String(format: "%.4f", location.coordinate.latitude)),
      URLQueryItem(name: "longitude", value: String(format: "%.4f", location.coordinate.longitude)),
      URLQueryItem(
        name: "hourly",
        value:
          "temperature_2m,relative_humidity_2m,rain,snowfall,snow_depth,wind_speed_10m"),
      URLQueryItem(name: "past_days", value: String(pastDays)),
      URLQueryItem(name: "forecast_days", value: "1"),
      URLQueryItem(name: "wind_speed_unit", value: "ms"),
      URLQueryItem(name: "timeformat", value: "unixtime"),
      URLQueryItem(name: "timezone", value: "UTC"),
    ]

    guard let url = components?.url else { throw ProviderError.badURL }

    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    request.cachePolicy = .returnCacheDataElseLoad

    let (data, response) = try await session.data(for: request)

    if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
      throw ProviderError.badResponse(http.statusCode)
    }

    let decoded = try JSONDecoder().decode(Response.self, from: data)
    let hourly = decoded.hourly

    guard !hourly.time.isEmpty else { throw ProviderError.emptyPayload }

    func value(_ array: [Double?]?, _ index: Int) -> Double? {
      guard let array, index < array.count else { return nil }
      return array[index]
    }

    let points: [WeatherDataPointModel] = hourly.time.indices.compactMap { index in
      guard let temperature = value(hourly.temperature2m, index) else { return nil }

      let start = Date(timeIntervalSince1970: TimeInterval(hourly.time[index]))
      let end = start.addingTimeInterval(3600)
      guard end > interval.start, start <= interval.end else { return nil }

      // Open-Meteo units: snowfall in cm, snow_depth in m, rain in mm.
      let snowfallMM = (value(hourly.snowfall, index) ?? 0) * 10.0
      let snowDepthCM = value(hourly.snowDepth, index).map { $0 * 100.0 }
      let humidity = value(hourly.relativeHumidity2m, index).map { $0 / 100.0 }

      return WeatherDataPointModel(
        start: start,
        end: end,
        averageAmountOfSnow: snowfallMM,
        averageAmountOfRain: value(hourly.rain, index) ?? 0,
        averageTemperature: temperature,
        relativeHumidity: humidity,
        windSpeed: value(hourly.windSpeed10m, index),
        snowDepthCM: snowDepthCM
      )
    }

    guard !points.isEmpty else { throw ProviderError.emptyPayload }

    if granularity == .daily {
      return collapseToDaily(points)
    }
    return points.sorted { $0.start < $1.start }
  }

  // MARK: - Helpers

  private func collapseToDaily(_ points: [WeatherDataPointModel]) -> [WeatherDataPointModel] {
    let calendar = Calendar.current
    let grouped = Dictionary(grouping: points) { calendar.startOfDay(for: $0.start) }

    return grouped.keys.sorted().compactMap { day -> WeatherDataPointModel? in
      guard let bucket = grouped[day], !bucket.isEmpty else { return nil }
      let humidities = bucket.compactMap(\.relativeHumidity)
      let winds = bucket.compactMap(\.windSpeed)

      return WeatherDataPointModel(
        start: day,
        end: calendar.date(byAdding: .day, value: 1, to: day) ?? day,
        averageAmountOfSnow: bucket.reduce(0) { $0 + $1.averageAmountOfSnow },
        averageAmountOfRain: bucket.reduce(0) { $0 + $1.averageAmountOfRain },
        averageTemperature: bucket.reduce(0) { $0 + $1.averageTemperature } / Double(bucket.count),
        relativeHumidity: humidities.isEmpty
          ? nil : humidities.reduce(0, +) / Double(humidities.count),
        windSpeed: winds.max(),
        snowDepthCM: bucket.compactMap(\.snowDepthCM).last
      )
    }
  }
}

// MARK: - Composite

/// Runs WeatherKit first and falls back to Open-Meteo when it fails, then
/// enriches the result with the signals WeatherKit does not provide.
public struct LayeredWeatherProviderFactory: WeatherProviderFactory {
  public init() {}
  public func makeProvider() -> WeatherProvider {
    LayeredWeatherProvider(
      primary: WeatherKitWeatherProvider(),
      secondary: OpenMeteoWeatherProvider()
    )
  }
}

public struct LayeredWeatherProvider: WeatherProvider {
  let primary: any WeatherProvider
  let secondary: any WeatherProvider

  public init(primary: any WeatherProvider, secondary: any WeatherProvider) {
    self.primary = primary
    self.secondary = secondary
  }

  public var sourceName: String { primary.sourceName }

  public func data(
    for location: CLLocation,
    in interval: DateInterval,
    granularity: WeatherGranularity
  ) async throws -> [WeatherDataPointModel] {
    async let primaryTask = try? primary.data(
      for: location, in: interval, granularity: granularity)
    async let secondaryTask = try? secondary.data(
      for: location, in: interval, granularity: granularity)

    let primaryPoints = await primaryTask ?? []
    let secondaryPoints = await secondaryTask ?? []

    if primaryPoints.isEmpty {
      guard !secondaryPoints.isEmpty else {
        // Surface the primary provider's real error rather than an empty array.
        return try await primary.data(for: location, in: interval, granularity: granularity)
      }
      logger.notice("WeatherKit unavailable; using \(secondary.sourceName, privacy: .public)")
      return secondaryPoints
    }

    guard !secondaryPoints.isEmpty else { return primaryPoints }

    return merge(primary: primaryPoints, secondary: secondaryPoints)
  }

  /// Keeps the primary provider's temperature and precipitation, and fills in
  /// humidity and snow depth from the secondary where the primary is silent.
  private func merge(
    primary: [WeatherDataPointModel],
    secondary: [WeatherDataPointModel]
  ) -> [WeatherDataPointModel] {
    var byHour: [Date: WeatherDataPointModel] = [:]
    for point in secondary {
      byHour[point.start.hourTruncated] = point
    }

    return primary.map { point in
      guard let extra = byHour[point.start.hourTruncated] else { return point }
      return WeatherDataPointModel(
        start: point.start,
        end: point.end,
        averageAmountOfSnow: point.averageAmountOfSnow,
        averageAmountOfRain: point.averageAmountOfRain,
        averageTemperature: point.averageTemperature,
        relativeHumidity: point.relativeHumidity ?? extra.relativeHumidity,
        windSpeed: point.windSpeed ?? extra.windSpeed,
        snowDepthCM: point.snowDepthCM ?? extra.snowDepthCM
      )
    }
  }
}

extension Date {
  fileprivate var hourTruncated: Date {
    Date(timeIntervalSince1970: (timeIntervalSince1970 / 3600).rounded(.down) * 3600)
  }
}
