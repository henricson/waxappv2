import CoreLocation
import Foundation

public struct WeatherDataPointModel: Sendable, Equatable {
  public let start: Date
  public let end: Date
  public let averageTemperature: Double
  public let averageAmountOfSnow: Double
  public let averageAmountOfRain: Double
  public var averageAmountOfPrecipitation: Double { averageAmountOfSnow + averageAmountOfRain }

  public init(
    start: Date,
    end: Date,
    averageAmountOfSnow: Double,
    averageAmountOfRain: Double,
    averageTemperature: Double
  ) {
    self.start = start
    self.end = end
    self.averageAmountOfSnow = averageAmountOfSnow
    self.averageAmountOfRain = averageAmountOfRain
    self.averageTemperature = averageTemperature
  }

}

public enum WeatherGranularity: Sendable {
  case hourly
  case daily
}

public protocol WeatherProvider: Sendable {
  func data(
    for location: CLLocation,
    in interval: DateInterval,
    granularity: WeatherGranularity
  ) async throws -> [WeatherDataPointModel]
}

public protocol WeatherProviderFactory: Sendable {
  func makeProvider() -> WeatherProvider
}
