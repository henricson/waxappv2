import Foundation
import CoreLocation
import WeatherKit
import Playgrounds

public struct WeatherKitWeatherProviderFactory: WeatherProviderFactory {
    public init() {}
    public func makeProvider() -> WeatherProvider { WeatherKitWeatherProvider() }
}

public struct WeatherKitWeatherProvider: WeatherProvider {
    public init() {}

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
                    averageTemperature: day.highTemperature.converted(to: .celsius).value
                )
            }

        case .hourly:
            let forecast = try await WeatherService.shared.weather(
                for: location,
                including: .hourly(startDate: interval.start, endDate: interval.end)
            )
            return forecast.forecast.map { hour in
                let rainMM = hour.precipitationAmount.converted(to: .millimeters).value
                let snowMM = hour.snowfallAmount.converted(to: .millimeters).value

                return WeatherDataPointModel(
                    start: hour.date,
                    end: hour.date.addingTimeInterval(3600),
                    averageAmountOfSnow: snowMM,
                    averageAmountOfRain: rainMM,
                    averageTemperature: hour.temperature.value
                )
            }
        }
    }
}

#Playground {
    var weatherFactory = WeatherKitWeatherProviderFactory().makeProvider()
    let kirkenes = CLLocation(latitude: 69.725, longitude: 30.051)
    let now = Date()
    let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: now)!
    let interval = DateInterval(start: tenDaysAgo, end: now)

    Task {
        do {
            let dataPoints = try await weatherFactory.data(for: kirkenes, in: interval, granularity: .hourly)
            for point in dataPoints {
                print("\(point.start) - snow: \(point.averageAmountOfSnow) mm, rain: \(point.averageAmountOfRain) mm, precip: \(point.averageAmountOfPrecipitation) mm")
            }
        } catch {
            print("Failed to fetch weather data:", error)
        }
    }
}
