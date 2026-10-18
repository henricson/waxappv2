import CoreLocation
import Foundation

public nonisolated struct WeatherDataPointModel: Sendable, Equatable {
  public let start: Date
  public let end: Date

  /// Air temperature, always °C.
  public let averageTemperature: Double

  /// Snowfall over the period, mm of snow depth.
  public let averageAmountOfSnow: Double

  /// Liquid precipitation over the period, mm. Excludes snowfall.
  public let averageAmountOfRain: Double

  /// Relative humidity, 0…1. `nil` when the provider doesn't report it.
  public let relativeHumidity: Double?

  /// Wind speed, m/s. `nil` when the provider doesn't report it.
  public let windSpeed: Double?

  /// Snow lying on the ground, cm. `nil` when the provider doesn't report it.
  public let snowDepthCM: Double?

  public var averageAmountOfPrecipitation: Double { averageAmountOfSnow + averageAmountOfRain }

  public init(
    start: Date,
    end: Date,
    averageAmountOfSnow: Double,
    averageAmountOfRain: Double,
    averageTemperature: Double,
    relativeHumidity: Double? = nil,
    windSpeed: Double? = nil,
    snowDepthCM: Double? = nil
  ) {
    self.start = start
    self.end = end
    self.averageAmountOfSnow = averageAmountOfSnow
    self.averageAmountOfRain = averageAmountOfRain
    self.averageTemperature = averageTemperature
    self.relativeHumidity = relativeHumidity
    self.windSpeed = windSpeed
    self.snowDepthCM = snowDepthCM
  }
}

public nonisolated enum WeatherGranularity: Sendable {
  case hourly
  case daily
}

public protocol WeatherProvider: Sendable {
  /// A short identifier for attribution and diagnostics.
  var sourceName: String { get }

  func data(
    for location: CLLocation,
    in interval: DateInterval,
    granularity: WeatherGranularity
  ) async throws -> [WeatherDataPointModel]
}

extension WeatherProvider {
  public var sourceName: String { String(describing: Self.self) }
}

public protocol WeatherProviderFactory: Sendable {
  func makeProvider() -> WeatherProvider
}
