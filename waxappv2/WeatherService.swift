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

public enum SnowSurfaceGroup: String, Sendable, CaseIterable, Identifiable {
    case group1 // Fallende/nylig falt snø med skarpe krystaller
    case group2 // Mellomstadiet / finkornet
    case group3 // Gammel snø / avrundet og bundet
    case group4 // Våt snø
    case group5 // Frosset / refrosset (skare/is)

    public var id: String { rawValue }

    public var titleNo: String {
        switch self {
        case .group1: return "Gruppe 1"
        case .group2: return "Gruppe 2"
        case .group3: return "Gruppe 3"
        case .group4: return "Gruppe 4"
        case .group5: return "Gruppe 5"
        }
    }

    public var descriptionNo: String {
        switch self {
        case .group1:
            return "Fallende og nylig falt snø preget av relativt skarpe krystaller; krever relativt hard ski-voks."
        case .group2:
            return "Mellomstadium i transformasjonen, ofte kalt finkornet snø."
        case .group3:
            return "Siste stadiet i transformasjonen: uniforme, avrundede, bundne korn (gammel snø)."
        case .group4:
            return "Våt snø: når snø i gruppe 1–3 utsettes for varmt vær."
        case .group5:
            return "Frosset/refrosset: våt snø som har frosset til, ofte hard/isete (skare)."
        }
    }
}

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

public struct SnowSurfaceAssessment: Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let group: SnowSurfaceGroup
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
    private let recentSnowThresholdCM: Double = 2.0     // >= 2 cm deemed “new/noticeable”
    private let wetTempCThreshold: Double = 0.0         // above freezing
    private let wetHoursThreshold: Int = 2              // hours above freezing to count as “wet”
    private let refreezeNightBelowC: Double = -1.0      // night min <= -1°C counts as refreeze
    private let daysWithoutSnowForGroup2: Int = 1       // 1–3 days without snow tends to group 2
    private let daysWithoutSnowForGroup3: Int = 4       // >=4–5 days without snow tends to group 3

    // MARK: Public API

    func fetchWeatherAndAssessSnow(for location: CLLocation) async throws -> WeatherAndSnowpackSummary {
        try await fetchWeatherAndAssessSnow(for: location.coordinate)
    }

    func fetchWeatherAndAssessSnow(for coordinate: CLLocationCoordinate2D) async throws -> WeatherAndSnowpackSummary {
        // WeatherKit expects a CLLocation for fetching weather.
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        // let weather = try await service.weather(for: clLocation)
        
        // Specify the date range for the last 7 days
        let calendar = Calendar.current
        // end date tomorrow
        let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        
        // Fetch hourly weather data
        let weather = try await service.weather(for: clLocation, including: .daily(startDate: startDate, endDate: endDate), .hourly(startDate: startDate, endDate: endDate))

        // Build WeatherSummary
        let summary = buildWeatherSummary(dailyWeather: weather.0, hourlyWeather: weather.1)

        // Build assessments for past daily (historical) using daily summaries
        let pastDailyAssessments = assessPastDaily(pastDaily: summary.pastDaily)

        // Current assessment from the most recent hourly entry (now or next)
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
        let pastDaily = dailyWeather.forecast
            .filter { calendar.startOfDay(for: $0.date) < today }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { day in
                DailyHistorySummary(
                    date: day.date,
                    // highTemperature and lowTemperature are non-optional Measurement<UnitTemperature>
                    temperatureMinC: day.lowTemperature.converted(to: .celsius).value,
                    temperatureMaxC: day.highTemperature.converted(to: .celsius).value,
                    totalPrecipitationMM: Self.mm(from: day.precipitationAmount),
                    snowfallAmountCM: Self.cm(from: day.snowfallAmount),
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
            pastDaily: Array(pastDaily),
            next24Hours: Array(next24Hours)
        )
    }

    // MARK: - Assessments

    private func assessPastDaily(pastDaily: [DailyHistorySummary]) -> [SnowSurfaceAssessment] {
        // We’ll scan from newest to oldest, tracking “days since last snow”
        var daysSinceSnow = 0
        var assessments: [SnowSurfaceAssessment] = []

        for day in pastDaily {
            let snowCM = day.snowfallAmountCM ?? Self.estimateSnowFromPrecip(totalMM: day.totalPrecipitationMM, precipitation: day.predominantPrecipitation)
            let minC = day.temperatureMinC
            let maxC = day.temperatureMaxC

            var reasons: [String] = []
            var group: SnowSurfaceGroup = .group3 // default bias to “older/rounded” if nothing else stands out

            // Detect wetness/refreeze heuristically using daily min/max
            let wasWet = (maxC ?? -100) > wetTempCThreshold
            let refroze = wasWet && (minC ?? 100) <= refreezeNightBelowC

            // New/Recent snow detection
            if let snow = snowCM, snow >= recentSnowThresholdCM {
                group = .group1
                reasons.append("Nylig snøfall ca. \(Self.format(snow, unit: "cm")).")
                daysSinceSnow = 0
            } else {
                daysSinceSnow += 1
            }

            if group != .group1 {
                if wasWet {
                    group = .group4
                    reasons.append("Dagtemperatur over 0 °C indikerer våt snø.")
                    if refroze {
                        group = .group5
                        reasons.append("Påfølgende natt under \(Int(refreezeNightBelowC)) °C indikerer refrysing/skare.")
                    }
                } else {
                    // Dry surface, no recent snow: evolve from group 2 to 3 with time
                    if daysSinceSnow <= daysWithoutSnowForGroup2 {
                        group = .group2
                        reasons.append("Lite/ingen nysnø siste \(daysSinceSnow) d. og kaldt: finkornet mellomstadium.")
                    } else if daysSinceSnow >= daysWithoutSnowForGroup3 {
                        group = .group3
                        reasons.append("Flere dager uten nysnø og kaldt: gammel/avrundet snø.")
                    } else {
                        group = .group2
                        reasons.append("Noe tid uten nysnø: finkornet utvikling.")
                    }
                }
            }

            let assessment = SnowSurfaceAssessment(
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

        // Look back/around “now” within the next few hours window (we only have forward hours here).
        // We’ll infer wetness if current temp is above freezing or forecast soon.
        let hoursAboveZero = next24.prefix(6).filter { $0.temperatureC > wetTempCThreshold }.count
        let nowWet = first.temperatureC > wetTempCThreshold || hoursAboveZero >= wetHoursThreshold

        // Precip type/probability near now to detect ongoing snowfall
        let precipNowSnowy = (first.precipitation == .snow || first.precipitation == .mixed) && first.precipitationChance >= 0.3

        var reasons: [String] = []
        var group: SnowSurfaceGroup = .group3 // neutral default

        if precipNowSnowy {
            group = .group1
            reasons.append("Pågående/snarlig snøfall.")
        } else if nowWet {
            group = .group4
            reasons.append("Temperatur over 0 °C de nærmeste timene indikerer våt snø.")
        } else {
            // If it’s cold and no new snow imminently, pick 2 or 3 based on “how cold” and humidity
            if first.temperatureC <= -8 {
                group = .group3
                reasons.append("Kaldt og tørt; overflaten kan være eldre/avrundet.")
            } else {
                group = .group2
                reasons.append("Ingen umiddelbar nysnø; overflaten i mellomstadiet (finkornet).")
            }
        }

        return SnowSurfaceAssessment(
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
            // Approximate 1 mm water ~ 1 cm snow (very rough; density varies widely)
            return totalMM // cm
        case .mixed:
            // Assume half snow, half rain
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
    // Expose assessment logic to the test target without making it public.
    internal func test_assessPastDaily(_ pastDaily: [DailyHistorySummary]) -> [SnowSurfaceAssessment] {
        return assessPastDaily(pastDaily: pastDaily)
    }

    internal func test_assessCurrentFromHourly(_ next24: [HourlyForecastEntry]) -> SnowSurfaceAssessment? {
        return assessCurrentFromHourly(next24: next24)
    }
}
