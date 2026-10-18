import CoreLocation
import Foundation
import WeatherKit

public struct WeatherKitWeatherProviderFactory: WeatherProviderFactory {
  public init() {}
  public func makeProvider() -> WeatherProvider { WeatherKitWeatherProvider() }
}

public struct WeatherKitWeatherProvider: WeatherProvider {
  public init() {}

  public var sourceName: String { "Apple Weather" }

  public func data(
    for location: CLLocation,
    in interval: DateInterval,
    granularity: WeatherGranularity
  ) async throws -> [WeatherDataPointModel] {
    switch granularity {
    case .daily:
      let forecast = try await WeatherService.shared.weather(
        for: location,
        including: .daily(startDate: interval.start, endDate: interval.end)
      )
      let calendar = Calendar.current
      return forecast.forecast.map { day in
        let byType = day.precipitationAmountByType
        let snowMM = byType.snowfallAmount.amount.converted(to: .millimeters).value
        let rainMM = byType.rainfall.converted(to: .millimeters).value
        let sleetMM = byType.sleet.converted(to: .millimeters).value
        let mixedMM = byType.mixed.converted(to: .millimeters).value
        let hailMM = byType.hail.converted(to: .millimeters).value

        let dayStart = calendar.startOfDay(for: day.date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        return WeatherDataPointModel(
          start: dayStart,
          end: dayEnd,
          averageAmountOfSnow: snowMM,
          averageAmountOfRain: rainMM + sleetMM + mixedMM + hailMM,
          averageTemperature: day.highTemperature.converted(to: .celsius).value,
          relativeHumidity: nil,
          windSpeed: day.wind.speed.converted(to: .metersPerSecond).value
        )
      }

    case .hourly:
      let forecast = try await WeatherService.shared.weather(
        for: location,
        including: .hourly(startDate: interval.start, endDate: interval.end)
      )
      return forecast.forecast.map { hour in
        // `precipitationAmount` is total liquid-equivalent precipitation and
        // already accounts for anything that fell as snow, so deriving rain as
        // (total − snow liquid-equivalent) avoids double-counting.
        let totalLiquidMM = hour.precipitationAmount.converted(to: .millimeters).value
        let snowDepthMM = hour.snowfallAmount.converted(to: .millimeters).value

        // Fresh snow is roughly a tenth the density of water; this is the
        // standard 10:1 approximation used for snow-water equivalent.
        let snowLiquidEquivalentMM = snowDepthMM / 10.0
        let rainMM = max(0, totalLiquidMM - snowLiquidEquivalentMM)

        return WeatherDataPointModel(
          start: hour.date,
          end: hour.date.addingTimeInterval(3600),
          averageAmountOfSnow: snowDepthMM,
          averageAmountOfRain: rainMM,
          averageTemperature: hour.temperature.converted(to: .celsius).value,
          relativeHumidity: hour.humidity,
          windSpeed: hour.wind.speed.converted(to: .metersPerSecond).value
        )
      }
    }
  }
}
