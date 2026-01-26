//
//  WeatherService.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import Foundation
import WeatherKit
import CoreLocation

// MARK: - Public Models

public struct DailyHistorySummary: Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let temperatureMinC: Double?
    public let temperatureMaxC: Double?
    public let totalPrecipitationMM: Double?
    public let snowfallAmountCM: Double?
    public let predominantPrecipitation: Precipitation?
}

public struct HourlyForecastEntry: Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let temperatureC: Double
    public let precipitationChance: Double // 0.0 - 1.0
    public let precipitation: Precipitation?
    public let relativeHumidity: Double? // 0.0 - 1.0
}

public struct WeatherSummary: Sendable {
    public let pastDaily: [DailyHistorySummary]   // newest past day first
    public let next24Hours: [HourlyForecastEntry] // starting from now
}

// Updated to use SwixSnowGroup from Data.swift
public struct SnowSurfaceAssessment: Sendable, Identifiable, Equatable {
    public var id: UUID
    
    public let date: Date
    public let group: SnowType
    public let reasons: [String] // brief heuristic rationale (Norwegian)
    // Supporting metrics (for debugging/inspection)
    public let recentSnowCM: Double?
    public let minTempC: Double?
    public let maxTempC: Double?
    public let hoursAboveZero: Int?
    public let refreezeDetected: Bool?
}

public struct WeatherAndSnowpackSummary: Sendable {
    public let weather: WeatherSummary
    public let pastDailyAssessments: [SnowSurfaceAssessment] // aligned to weather.pastDaily dates
    public let currentAssessment: SnowSurfaceAssessment?     // based on the most recent hour
}

// MARK: - Weather Service Client

@MainActor
final class WeatherServiceClient {
    private let service = WeatherKit.WeatherService()

    // Tunable thresholds (metric)
    private let recentSnowThresholdCM: Double = 1.0     // >= 2 cm deemed “new/noticeable”
    private let wetTempCThreshold: Double = 0.0         // above freezing
    private let wetHoursThreshold: Int = 2              // hours above freezing to count as “wet”
    private let refreezeNightBelowC: Double = -1.0      // night min <= -1°C counts as refreeze
    private let daysWithoutSnowForFine: Int = 1         // 0–1 days -> fineGrained
    private let daysWithoutSnowForOld: Int = 4          // >=4–5 days -> oldGrained

    // MARK: Public API

    func fetchWeatherAndAssessSnow(for location: CLLocation) async throws -> WeatherAndSnowpackSummary {
        try await fetchWeatherAndAssessSnow(for: location.coordinate)
    }

    func fetchWeatherAndAssessSnow(for coordinate: CLLocationCoordinate2D) async throws -> WeatherAndSnowpackSummary {
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Specify the date range for the last 7 days + tomorrow
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!

        // Fetch daily and hourly weather data
        let weather = try await service.weather(
            for: clLocation,
            including: .daily(startDate: startDate, endDate: endDate),
            .hourly(startDate: startDate, endDate: endDate)
        )

        let summary = buildWeatherSummary(dailyWeather: weather.0, hourlyWeather: weather.1)
        let pastDailyAssessments = assessPastDaily(pastDaily: summary.pastDaily)
        let currentAssessment = assessCurrentFromHourly(next24: summary.next24Hours)

        return WeatherAndSnowpackSummary(
            weather: summary,
            pastDailyAssessments: pastDailyAssessments,
            currentAssessment: currentAssessment
        )
    }

    // MARK: - Build WeatherSummary

    private func buildWeatherSummary(dailyWeather: Forecast<DayWeather>, hourlyWeather: Forecast<HourWeather>) -> WeatherSummary {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let today = calendar.startOfDay(for: now)

        // Past daily: include only days strictly before today, newest first, up to 10
        let filteredDays = dailyWeather.forecast.filter { calendar.startOfDay(for: $0.date) < today }
        let sortedDays = filteredDays.sorted { $0.date > $1.date }
        let recentDays = Array(sortedDays.prefix(10))
        
        let pastDaily: [DailyHistorySummary] = recentDays.map { day in
            let precipitationMM: Double
            let snowFallAmountCM: Double?
            if #available(iOS 18.0, *) {
                let byType = day.precipitationAmountByType
                let rain = Self.mm(from: byType.rainfall) ?? 0
                let snow = Self.mm(from: byType.snowfallAmount.amount) ?? 0
                let sleet = Self.mm(from: byType.sleet) ?? 0
                let hail = Self.mm(from: byType.hail) ?? 0
                let mixed = Self.mm(from: byType.mixed) ?? 0
                precipitationMM = rain + snow + sleet + hail + mixed
                snowFallAmountCM = snow / 10.0  // Convert mm to cm
            } else {
                precipitationMM = Self.mm(from: day.precipitationAmount) ?? 0
                snowFallAmountCM = Self.cm(from: day.snowfallAmount)
            }
            
            return DailyHistorySummary(
                date: day.date,
                temperatureMinC: day.lowTemperature.converted(to: .celsius).value,
                temperatureMaxC: day.highTemperature.converted(to: .celsius).value,
                totalPrecipitationMM: precipitationMM,
                snowfallAmountCM: snowFallAmountCM,
                predominantPrecipitation: day.precipitation
            )
        }

        // Next 24 hours from now
        let next24Hours = hourlyWeather.forecast
            .filter { $0.date >= now }
            .prefix(24)
            .map { hour in
                HourlyForecastEntry(
                    date: hour.date,
                    temperatureC: hour.temperature.converted(to: .celsius).value,
                    precipitationChance: hour.precipitationChance,
                    precipitation: hour.precipitation,
                    relativeHumidity: hour.humidity
                )
            }

        return WeatherSummary(
            pastDaily: pastDaily,
            next24Hours: Array(next24Hours)
        )
    }

    // MARK: - Assessments (mapped to SwixSnowGroup)

    private func assessPastDaily(pastDaily: [DailyHistorySummary]) -> [SnowSurfaceAssessment] {
        var daysSinceSnow = 0
        var assessments: [SnowSurfaceAssessment] = []

        for day in pastDaily {
            let snowCM = day.snowfallAmountCM ?? Self.estimateSnowFromPrecip(totalMM: day.totalPrecipitationMM, precipitation: day.predominantPrecipitation)
            let minC = day.temperatureMinC
            let maxC = day.temperatureMaxC

            var reasons: [String] = []
            var group: SnowType = .fineGrained // neutral default leaning to fine

            let wasWet = (maxC ?? -100) > wetTempCThreshold
            let refroze = wasWet && (minC ?? 100) <= refreezeNightBelowC

            // New/Recent snow detection
            if let snow = snowCM, snow >= recentSnowThresholdCM {
                // If near or above 0°C we consider moist new fallen
                if (maxC ?? -100) >= -1 {
                    group = .moistNewFallen
                    reasons.append("Nylig snøfall ca. \(Self.format(snow, unit: "cm")), fuktig/omkring 0 °C.")
                } else {
                    group = .newFallen
                    reasons.append("Nylig snøfall ca. \(Self.format(snow, unit: "cm")).")
                }
                daysSinceSnow = 0
            } else {
                daysSinceSnow += 1
            }

            if group != .newFallen && group != .moistNewFallen {
                if wasWet {
                    // Wet spectrum
                    if refroze {
                        group = .frozenCorn
                        reasons.append("Varm dag fulgt av natt ≤ \(Int(refreezeNightBelowC)) °C: refrysing/skare.")
                    } else {
                        // Distinguish wetness roughly by max temp
                        if (maxC ?? 0) >= 3 {
                            group = .veryWetCorn
                            reasons.append("Svært våt/slush: høy temperatur over 0 °C.")
                        } else {
                            group = .wetCorn
                            reasons.append("Våt snø: dagtemperatur over 0 °C.")
                        }
                    }
                } else {
                    // Dry surface, no recent snow: evolve from fine to old
                    if daysSinceSnow <= daysWithoutSnowForFine {
                        // Around 0 with humidity but not wet -> transformed/moist fine
                        if let maxC, maxC >= -1 && maxC < 1 {
                            group = .transformedMoistFine
                            reasons.append("Nær 0 °C, fuktig/omvandlet finkornet.")
                        } else {
                            group = .fineGrained
                            reasons.append("Lite/ingen nysnø siste \(daysSinceSnow) d. og kaldt: finkornet.")
                        }
                    } else if daysSinceSnow >= daysWithoutSnowForOld {
                        group = .oldGrained
                        reasons.append("Flere dager uten nysnø og kaldt: gammel/avrundet snø.")
                    } else {
                        // intermediate dry-but-not-old yet; if slightly humid choose moistFineGrained
                        if let maxC, maxC >= -2 && maxC <= 0 {
                            group = .moistFineGrained
                            reasons.append("Fuktig finkornet nær 0 °C.")
                        } else {
                            group = .fineGrained
                            reasons.append("Noe tid uten nysnø: finkornet utvikling.")
                        }
                    }
                }
            }

            let assessment = SnowSurfaceAssessment(
                id: UUID(),
                date: day.date,
                group: group,
                reasons: reasons,
                recentSnowCM: snowCM,
                minTempC: minC,
                maxTempC: maxC,
                hoursAboveZero: nil,
                refreezeDetected: wasWet && refroze
            )
            assessments.append(assessment)
        }

        return assessments
    }

    private func assessCurrentFromHourly(next24: [HourlyForecastEntry]) -> SnowSurfaceAssessment? {
        guard let first = next24.first else { return nil }

        let hoursAboveZero = next24.prefix(6).filter { $0.temperatureC > wetTempCThreshold }.count
        let nowWet = first.temperatureC > wetTempCThreshold || hoursAboveZero >= wetHoursThreshold

        // Snow imminent/ongoing
        let precipNowSnowy = (first.precipitation == .snow || first.precipitation == .mixed) && first.precipitationChance >= 0.3

        var reasons: [String] = []
        var group: SnowType = .fineGrained

        if precipNowSnowy {
            if first.temperatureC >= -1 {
                group = .moistNewFallen
                reasons.append("Pågående/snarlig snøfall i fuktige/varme forhold.")
            } else {
                group = .newFallen
                reasons.append("Pågående/snarlig snøfall.")
            }
        } else if nowWet {
            // Distinguish wetness level by temperature trend
            if hoursAboveZero >= 4 || first.temperatureC >= 3 {
                group = .veryWetCorn
                reasons.append("Svært våt/slush de nærmeste timene.")
            } else {
                group = .wetCorn
                reasons.append("Temperatur over 0 °C indikerer våt snø.")
            }
        } else {
            // Dry: choose between fine vs old vs transformed near 0
            if first.temperatureC <= -8 {
                group = .oldGrained
                reasons.append("Kaldt og tørt; overflaten kan være eldre/avrundet.")
            } else if first.temperatureC >= -1 && first.temperatureC <= 1 {
                group = .transformedMoistFine
                reasons.append("Nær 0 °C og fuktig; omvandlet finkornet.")
            } else {
                group = .fineGrained
                reasons.append("Ingen umiddelbar nysnø; finkornet.")
            }
        }

        return SnowSurfaceAssessment(
            id: UUID(),
            date: first.date,
            group: group,
            reasons: reasons,
            recentSnowCM: nil,
            minTempC: nil,
            maxTempC: nil,
            hoursAboveZero: hoursAboveZero,
            refreezeDetected: nil
        )
    }

    // MARK: - Helpers

    private static func mm(from amount: Measurement<UnitLength>?) -> Double? {
        guard let amount else { return nil }
        return amount.converted(to: .millimeters).value
    }

    private static func cm(from amount: Measurement<UnitLength>?) -> Double? {
        guard let amount else { return nil }
        return amount.converted(to: .centimeters).value
    }

    /// If snowfallAmount is unavailable, estimate snow from total precip if type indicates snow/mixed.
    private static func estimateSnowFromPrecip(totalMM: Double?, precipitation: Precipitation?) -> Double? {
        guard let totalMM, totalMM > 0 else { return nil }
        guard let precipitation else { return nil }

        switch precipitation {
        case .snow:
            return totalMM // cm (approx)
        case .mixed:
            return totalMM * 0.5
        default:
            return nil
        }
    }

    private static func format(_ value: Double, unit: String) -> String {
        let f = NumberFormatter()
        f.maximumFractionDigits = 1
        return "\(f.string(from: NSNumber(value: value)) ?? "\(value)") \(unit)"
    }
}

// MARK: - Internal test shim

extension WeatherServiceClient {
    internal func test_assessPastDaily(_ pastDaily: [DailyHistorySummary]) -> [SnowSurfaceAssessment] {
        return assessPastDaily(pastDaily: pastDaily)
    }

    internal func test_assessCurrentFromHourly(_ next24: [HourlyForecastEntry]) -> SnowSurfaceAssessment? {
        return assessCurrentFromHourly(next24: next24)
    }
}
