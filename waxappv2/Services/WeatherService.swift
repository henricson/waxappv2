//
//  WeatherService.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//  Refactored with expert snow classification based on Swix wax manual
//  and snow metamorphism science from SLF, Cambridge Glaciology, etc.
//
//  Swix 5-Group Classification:
//  Group 1: New fallen snow (sharp crystals) → Hard wax
//  Group 2: Fine-grained (intermediate transformation) → Hard wax
//  Group 3: Old/coarse-grained (fully transformed) → Hard wax (klister if warming)
//  Group 4: Wet snow (above freezing, liquid water present) → Soft wax / Klister
//  Group 5: Frozen/refrozen (was wet, now frozen) → Klister
//
//  KEY RULE: You can only reach Group 5 by going through Group 4 first!
//  New snow resets the surface condition.
//

import Foundation
import WeatherKit
import CoreLocation

// MARK: - Localization Key References

private func _weatherServiceLocalizationKeys() {
    // Assessment reasons - New snow
    _ = String(localized: "Snow_Reason_NewSnow_Moist")
    _ = String(localized: "Snow_Reason_NewSnow_Dry")
    _ = String(localized: "Snow_Reason_NewSnow_Imminent_Moist")
    _ = String(localized: "Snow_Reason_NewSnow_Imminent_Dry")
    
    // Assessment reasons - Frozen/Refrozen
    _ = String(localized: "Snow_Reason_MeltFreezeCycle")
    _ = String(localized: "Snow_Reason_RefrozenAfterMelt")
    _ = String(localized: "Snow_Reason_YesterdayWetNowFrozen")
    
    // Assessment reasons - Wet conditions
    _ = String(localized: "Snow_Reason_VeryWet_HighTemp")
    _ = String(localized: "Snow_Reason_VeryWet_Forecast")
    _ = String(localized: "Snow_Reason_WetCorn_Warming")
    _ = String(localized: "Snow_Reason_WetCorn_AboveFreezing")
    _ = String(localized: "Snow_Reason_TransformedMoist_NearZero")
    _ = String(localized: "Snow_Reason_TransformedMoist_Warming")
    
    // Assessment reasons - Fine-grained
    _ = String(localized: "Snow_Reason_LightSnow_Moist")
    _ = String(localized: "Snow_Reason_LightSnow_Refreshed")
    _ = String(localized: "Snow_Reason_FineGrained_Recent")
    _ = String(localized: "Snow_Reason_FineGrained_MoistConditions")
    _ = String(localized: "Snow_Reason_FineGrained_Cold")
    _ = String(localized: "Snow_Reason_FineGrained_DaysSinceSnow")
    _ = String(localized: "Snow_Reason_FineGrained_Transitioning")
    _ = String(localized: "Snow_Reason_MoistFineGrained_Humidity")
    _ = String(localized: "Snow_Reason_MoistFineGrained_NearZero")
    
    // Assessment reasons - Old snow
    _ = String(localized: "Snow_Reason_OldSnow_Dry")
    _ = String(localized: "Snow_Reason_OldSnow_NearZero")
    
    // Wax guidance
    _ = String(localized: "WaxGuidance_NewFallen")
    _ = String(localized: "WaxGuidance_MoistNewFallen")
    _ = String(localized: "WaxGuidance_FineGrained")
    _ = String(localized: "WaxGuidance_MoistFineGrained")
    _ = String(localized: "WaxGuidance_OldGrained")
    _ = String(localized: "WaxGuidance_TransformedMoistFine")
    _ = String(localized: "WaxGuidance_WetCorn")
    _ = String(localized: "WaxGuidance_VeryWetCorn")
    _ = String(localized: "WaxGuidance_FrozenCorn")
    
    // Confidence levels
    _ = String(localized: "Confidence_High")
    _ = String(localized: "Confidence_Medium")
    _ = String(localized: "Confidence_Low")
}

// MARK: - Public Models

public struct DailyHistorySummary: Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let temperatureMinC: Double?
    public let temperatureMaxC: Double?
    public let totalPrecipitationMM: Double?
    public let snowfallAmountCM: Double?
    public let predominantPrecipitation: Precipitation?
    public let averageHumidity: Double?
}

public struct HourlyForecastEntry: Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let temperatureC: Double
    public let precipitationChance: Double
    public let precipitation: Precipitation?
    public let relativeHumidity: Double?
    public let windSpeedKmh: Double?
    public let cloudCover: Double?
}

public struct WeatherSummary: Sendable {
    public let pastDaily: [DailyHistorySummary]
    public let next24Hours: [HourlyForecastEntry]
}

// MARK: - Assessment Confidence

public enum AssessmentConfidence: String, Sendable, Equatable, CaseIterable {
    case high = "high"
    case medium = "medium"
    case low = "low"
    
    public var localizedName: String {
        switch self {
        case .high: return String(localized: "Confidence_High")
        case .medium: return String(localized: "Confidence_Medium")
        case .low: return String(localized: "Confidence_Low")
        }
    }
}

// MARK: - Snow Surface Assessment

public struct SnowSurfaceAssessment: Sendable, Identifiable, Equatable {
    public var id: UUID
    
    public let date: Date
    public let group: SnowType
    public let confidence: AssessmentConfidence
    public let reasonKeys: [String]
    public let reasonParams: [[String: String]]
    
    public let recentSnowCM: Double?
    public let minTempC: Double?
    public let maxTempC: Double?
    public let hoursAboveZero: Int?
    public let hoursBelowMinus5: Int?
    public let refreezeDetected: Bool?
    public let daysSinceLastMelt: Int?
    public let daysSinceSignificantSnow: Int?
    public let humidity: Double?
    
    public var reasons: [String] {
        zip(reasonKeys, reasonParams).map { key, params in
            var localized = String(localized: String.LocalizationValue(key))
            for (param, value) in params {
                localized = localized.replacingOccurrences(of: "{\(param)}", with: value)
            }
            return localized
        }
    }
    
    public var swixGroup: Int { group.swixGroup }
}

public struct WeatherAndSnowpackSummary: Sendable {
    public let weather: WeatherSummary
    public let pastDailyAssessments: [SnowSurfaceAssessment]
    public let currentAssessment: SnowSurfaceAssessment?
}

// MARK: - Snow Metamorphism State Tracker

/// Tracks cumulative snow state for accurate assessment
/// KEY INSIGHT: Surface condition is determined by the MOST RECENT significant event:
/// - New snow covers old surface → reset to Group 1
/// - Melting creates wet conditions → Group 4
/// - Refreezing of wet snow → Group 5
/// - Time without events → gradual transformation Groups 1→2→3
private struct SnowpackState {
    var daysSinceSignificantSnow: Int = 0      // Days since ≥2cm snowfall
    var daysSinceLastMelt: Int? = nil          // Days since temps went above 0°C (nil = no recent melt)
    var snowDepthSinceLastMelt: Double = 0     // Snow accumulated since last melt event
    var wasWetRecently: Bool = false           // Was there liquid water in snow recently?
    var consecutiveDaysAboveFreezing: Int = 0  // For tracking sustained warm periods
    
    /// Snow metamorphism rate depends on temperature
    /// At -10°C: baseline rate (factor = 1.0)
    /// Warmer = faster transformation, Colder = slower
    func metamorphismRateFactor(avgTempC: Double) -> Double {
        let baseTempC = -10.0
        let tempDiff = avgTempC - baseTempC
        return max(0.25, pow(2.0, tempDiff / 10.0)) // Minimum 0.25 for very cold
    }
    
    func effectiveAge(actualDays: Int, avgTempC: Double) -> Double {
        return Double(actualDays) * metamorphismRateFactor(avgTempC: avgTempC)
    }
    
    /// Check if surface is in refrozen state
    /// Requires: recent melt (within 3 days) AND not covered by significant new snow
    func isRefrozenSurface(currentTempC: Double) -> Bool {
        guard let daysSinceMelt = daysSinceLastMelt else { return false }
        
        // Must have melted recently (within 3 days)
        guard daysSinceMelt <= 3 else { return false }
        
        // Must not be covered by significant new snow since the melt
        guard snowDepthSinceLastMelt < 2.0 else { return false }
        
        // Must currently be below freezing
        guard currentTempC < 0 else { return false }
        
        return true
    }
}

// MARK: - Weather Service Client

@MainActor
final class WeatherServiceClient {
    private let service = WeatherKit.WeatherService()

    // MARK: - Thresholds
    
    // Snow amounts
    private let significantSnowCM: Double = 2.0       // Significant new layer
    private let lightSnowCM: Double = 0.5             // Light dusting
    private let surfaceCoverSnowCM: Double = 1.0      // Enough to cover old surface
    
    // Temperature boundaries (Celsius)
    private let freezingPoint: Double = 0.0
    private let moistSnowBoundary: Double = -1.0      // Above this = moist conditions possible
    private let coldSnowBoundary: Double = -7.0       // Below this = cold/dry conditions
    private let veryColdBoundary: Double = -12.0      // Below this = very slow metamorphism
    
    // Wet snow detection
    private let wetSnowTempThreshold: Double = 0.5    // Above this = definitely wet
    private let slushTempThreshold: Double = 2.0      // Above this = very wet/slushy
    
    // Time periods
    private let newSnowWindowDays: Int = 2            // Snow is "new" for up to 2 days
    private let fineGrainedMaxDays: Int = 4           // After this → old grained
    private let meltRelevanceWindowDays: Int = 3      // Melt affects surface for 3 days
    
    // Humidity
    private let highHumidityThreshold: Double = 0.80
    private let lowHumidityThreshold: Double = 0.50

    // MARK: - Public API

    func fetchWeatherAndAssessSnow(for location: CLLocation) async throws -> WeatherAndSnowpackSummary {
        try await fetchWeatherAndAssessSnow(for: location.coordinate)
    }

    func fetchWeatherAndAssessSnow(for coordinate: CLLocationCoordinate2D) async throws -> WeatherAndSnowpackSummary {
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!

        let weather = try await service.weather(
            for: clLocation,
            including: .daily(startDate: startDate, endDate: endDate),
            .hourly(startDate: startDate, endDate: endDate)
        )

        let summary = buildWeatherSummary(dailyWeather: weather.0, hourlyWeather: weather.1)
        let pastDailyAssessments = assessPastDailyWithHistory(pastDaily: summary.pastDaily)
        let currentAssessment = assessCurrentConditions(
            next24: summary.next24Hours,
            recentHistory: summary.pastDaily,
            historicalAssessments: pastDailyAssessments
        )

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

        let filteredDays = dailyWeather.forecast.filter { calendar.startOfDay(for: $0.date) < today }
        let sortedDays = filteredDays.sorted { $0.date > $1.date }
        let recentDays = Array(sortedDays.prefix(10))
        
        let hourlyByDay = Dictionary(grouping: hourlyWeather.forecast) {
            calendar.startOfDay(for: $0.date)
        }
        
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
                snowFallAmountCM = snow / 10.0
            } else {
                precipitationMM = Self.mm(from: day.precipitationAmount) ?? 0
                snowFallAmountCM = Self.cm(from: day.snowfallAmount)
            }
            
            let dayStart = calendar.startOfDay(for: day.date)
            let dayHours = hourlyByDay[dayStart] ?? []
            let avgHumidity: Double? = dayHours.isEmpty ? nil :
                dayHours.compactMap { $0.humidity }.reduce(0, +) / Double(dayHours.count)
            
            return DailyHistorySummary(
                date: day.date,
                temperatureMinC: day.lowTemperature.converted(to: .celsius).value,
                temperatureMaxC: day.highTemperature.converted(to: .celsius).value,
                totalPrecipitationMM: precipitationMM,
                snowfallAmountCM: snowFallAmountCM,
                predominantPrecipitation: day.precipitation,
                averageHumidity: avgHumidity
            )
        }

        let next24Hours = hourlyWeather.forecast
            .filter { $0.date >= now }
            .prefix(24)
            .map { hour in
                HourlyForecastEntry(
                    date: hour.date,
                    temperatureC: hour.temperature.converted(to: .celsius).value,
                    precipitationChance: hour.precipitationChance,
                    precipitation: hour.precipitation,
                    relativeHumidity: hour.humidity,
                    windSpeedKmh: hour.wind.speed.converted(to: .kilometersPerHour).value,
                    cloudCover: hour.cloudCover
                )
            }

        return WeatherSummary(
            pastDaily: pastDaily,
            next24Hours: Array(next24Hours)
        )
    }

    // MARK: - Historical Assessment

    private func assessPastDailyWithHistory(pastDaily: [DailyHistorySummary]) -> [SnowSurfaceAssessment] {
        // Process oldest to newest to build accurate state
        let chronological = pastDaily.reversed()
        
        var state = SnowpackState()
        var assessments: [SnowSurfaceAssessment] = []
        
        for day in chronological {
            let assessment = assessDay(day: day, state: &state)
            assessments.append(assessment)
            updateStateAfterDay(day: day, state: &state)
        }
        
        return assessments.reversed()
    }
    
    /// Core assessment logic following Swix classification
    /// Priority order:
    /// 1. Currently wet (above freezing) → Group 4
    /// 2. Recent significant snow → Group 1
    /// 3. Recently melted, now frozen, no new snow cover → Group 5
    /// 4. Dry snow transformation based on age → Groups 2-3
    private func assessDay(day: DailyHistorySummary, state: inout SnowpackState) -> SnowSurfaceAssessment {
        let snowCM = day.snowfallAmountCM ?? Self.estimateSnowFromPrecip(
            totalMM: day.totalPrecipitationMM,
            precipitation: day.predominantPrecipitation,
            maxTempC: day.temperatureMaxC
        )
        let minC = day.temperatureMinC ?? -5.0
        let maxC = day.temperatureMaxC ?? 0.0
        let avgC = (minC + maxC) / 2.0
        let humidity = day.averageHumidity ?? 0.65
        
        var reasonKeys: [String] = []
        var reasonParams: [[String: String]] = []
        var confidence: AssessmentConfidence = .medium
        let group: SnowType
        
        // Key conditions
        let hasSignificantSnow = (snowCM ?? 0) >= significantSnowCM
        let hasLightSnow = (snowCM ?? 0) >= lightSnowCM
        let isAboveFreezing = maxC > freezingPoint
        let isCurrentlyWet = maxC >= wetSnowTempThreshold
        let isVeryCold = avgC <= veryColdBoundary
        let isMoist = maxC >= moistSnowBoundary && maxC < wetSnowTempThreshold
        let isHighHumidity = humidity >= highHumidityThreshold
        
        // Check if this is a refrozen surface (was wet, now frozen, no significant new snow cover)
        let isRefrozen = state.isRefrozenSurface(currentTempC: avgC)
        
        // DECISION TREE
        
        // PRIORITY 1: Currently wet conditions (Group 4)
        // If temps are above freezing, snow is wet regardless of history
        if isCurrentlyWet {
            if maxC >= slushTempThreshold {
                group = .veryWetCorn
                reasonKeys.append("Snow_Reason_VeryWet_HighTemp")
                reasonParams.append(["temp": Self.format(maxC)])
                confidence = .high
            } else {
                group = .wetCorn
                reasonKeys.append("Snow_Reason_WetCorn_AboveFreezing")
                reasonParams.append(["temp": Self.format(maxC)])
                confidence = .high
            }
        }
        // PRIORITY 2: Significant new snow (Group 1)
        // Fresh snow covers any previous surface condition
        else if hasSignificantSnow {
            if maxC >= moistSnowBoundary {
                group = .moistNewFallen
                reasonKeys.append("Snow_Reason_NewSnow_Moist")
                reasonParams.append(["snow": Self.format(snowCM ?? 0)])
                confidence = .high
            } else {
                group = .newFallen
                reasonKeys.append("Snow_Reason_NewSnow_Dry")
                reasonParams.append(["snow": Self.format(snowCM ?? 0)])
                confidence = .high
            }
        }
        // PRIORITY 3: Refrozen conditions (Group 5)
        // Was wet recently, now frozen, and not covered by new snow
        else if isRefrozen && !isAboveFreezing {
            group = .frozenCorn
            reasonKeys.append("Snow_Reason_RefrozenAfterMelt")
            reasonParams.append(["temp": Self.format(avgC)])
            confidence = .high
        }
        // PRIORITY 4: Near-zero moist conditions (Group 4 variant)
        // Temperature close to 0 but below, with high humidity
        else if isMoist && isHighHumidity && !isVeryCold {
            group = .transformedMoistFine
            reasonKeys.append("Snow_Reason_TransformedMoist_NearZero")
            reasonParams.append(["temp": Self.format(maxC)])
            confidence = .medium
        }
        // PRIORITY 5: Dry snow transformation (Groups 1-3) based on ACTUAL days
        // Swix classification: Group 1 → Group 2 → Group 3
        else {
            let daysSinceSnow = state.daysSinceSignificantSnow
            let isCold = avgC <= coldSnowBoundary
            
            // Light snow refreshes surface (stays in Group 1-2 range)
            if hasLightSnow {
                if isMoist {
                    group = .moistFineGrained
                    reasonKeys.append("Snow_Reason_LightSnow_Moist")
                    reasonParams.append([:])
                } else {
                    group = .fineGrained
                    reasonKeys.append("Snow_Reason_LightSnow_Refreshed")
                    reasonParams.append([:])
                }
                confidence = .medium
            }
            // 0-1 days since snow: Group 1 (new fallen snow)
            else if daysSinceSnow <= 1 {
                if isMoist || isHighHumidity {
                    group = .moistNewFallen
                    reasonKeys.append("Snow_Reason_NewSnow_Moist")
                    reasonParams.append(["snow": "recent"])
                } else {
                    group = .newFallen
                    reasonKeys.append("Snow_Reason_NewSnow_Dry")
                    reasonParams.append(["snow": "recent"])
                }
                confidence = .high
            }
            // 2-4 days: Group 2 (fine-grained / intermediate)
            else if daysSinceSnow <= fineGrainedMaxDays {
                if isMoist {
                    group = .moistFineGrained
                    reasonKeys.append("Snow_Reason_MoistFineGrained_NearZero")
                    reasonParams.append(["temp": Self.format(maxC)])
                } else if isCold {
                    // Cold slows transformation - clearly still fine-grained
                    group = .fineGrained
                    reasonKeys.append("Snow_Reason_FineGrained_Cold")
                    reasonParams.append(["temp": Self.format(avgC)])
                    confidence = .high
                } else {
                    group = .fineGrained
                    reasonKeys.append("Snow_Reason_FineGrained_DaysSinceSnow")
                    reasonParams.append(["days": "\(daysSinceSnow)"])
                }
                confidence = .medium
            }
            // 5+ days: Group 3 (old grained / final transformation)
            else {
                if isMoist {
                    group = .transformedMoistFine
                    reasonKeys.append("Snow_Reason_OldSnow_NearZero")
                    reasonParams.append(["temp": Self.format(maxC)])
                    confidence = .medium
                } else {
                    group = .oldGrained
                    reasonKeys.append("Snow_Reason_OldSnow_Dry")
                    reasonParams.append(["days": "\(daysSinceSnow)"])
                    confidence = .high
                }
            }
        }
        
        return SnowSurfaceAssessment(
            id: UUID(),
            date: day.date,
            group: group,
            confidence: confidence,
            reasonKeys: reasonKeys,
            reasonParams: reasonParams,
            recentSnowCM: snowCM,
            minTempC: minC,
            maxTempC: maxC,
            hoursAboveZero: nil,
            hoursBelowMinus5: nil,
            refreezeDetected: isRefrozen,
            daysSinceLastMelt: state.daysSinceLastMelt,
            daysSinceSignificantSnow: state.daysSinceSignificantSnow,
            humidity: humidity
        )
    }
    
    private func updateStateAfterDay(day: DailyHistorySummary, state: inout SnowpackState) {
        let snowCM = day.snowfallAmountCM ?? Self.estimateSnowFromPrecip(
            totalMM: day.totalPrecipitationMM,
            precipitation: day.predominantPrecipitation,
            maxTempC: day.temperatureMaxC
        )
        let maxC = day.temperatureMaxC ?? 0.0
        
        // Update snow tracking
        if (snowCM ?? 0) >= significantSnowCM {
            state.daysSinceSignificantSnow = 0
            state.snowDepthSinceLastMelt += snowCM ?? 0
        } else {
            state.daysSinceSignificantSnow += 1
            if (snowCM ?? 0) > 0 {
                state.snowDepthSinceLastMelt += snowCM ?? 0
            }
        }
        
        // Update melt tracking
        if maxC >= wetSnowTempThreshold {
            // Melt event occurred
            state.daysSinceLastMelt = 0
            state.snowDepthSinceLastMelt = 0  // Reset - new snow after this is "since melt"
            state.wasWetRecently = true
            state.consecutiveDaysAboveFreezing += 1
        } else {
            // No melt today
            if let days = state.daysSinceLastMelt {
                state.daysSinceLastMelt = days + 1
                // After melt relevance window, reset
                if days + 1 > meltRelevanceWindowDays {
                    state.daysSinceLastMelt = nil
                    state.wasWetRecently = false
                }
            }
            state.consecutiveDaysAboveFreezing = 0
        }
    }

    // MARK: - Current Conditions Assessment

    private func assessCurrentConditions(
        next24: [HourlyForecastEntry],
        recentHistory: [DailyHistorySummary],
        historicalAssessments: [SnowSurfaceAssessment]
    ) -> SnowSurfaceAssessment? {
        guard let currentHour = next24.first else { return nil }
        
        let currentTemp = currentHour.temperatureC
        let humidity = currentHour.relativeHumidity ?? 0.65
        
        let next6Hours = Array(next24.prefix(6))
        let hoursAboveZero = next6Hours.filter { $0.temperatureC > freezingPoint }.count
        let hoursBelowMinus5 = next6Hours.filter { $0.temperatureC < coldSnowBoundary }.count
        let avgTempNext6 = next6Hours.map { $0.temperatureC }.reduce(0, +) / Double(max(1, next6Hours.count))
        
        // Check for imminent snow
        let snowImminent = next6Hours.contains { hour in
            (hour.precipitation == .snow || hour.precipitation == .mixed) && hour.precipitationChance >= 0.4
        }
        let heavySnowImminent = next6Hours.contains { hour in
            hour.precipitation == .snow && hour.precipitationChance >= 0.7
        }
        
        // Get context from yesterday's assessment
        let yesterdayAssessment = historicalAssessments.first
        let daysSinceLastMelt = yesterdayAssessment?.daysSinceLastMelt
        let wasYesterdayWet = yesterdayAssessment?.group == .wetCorn ||
                              yesterdayAssessment?.group == .veryWetCorn
        
        // Check for recent snow in history - look at actual snowfall data
        // This is the PRIMARY source of truth for recent snow
        let recentSnowfall = recentHistory.prefix(3).compactMap { $0.snowfallAmountCM }.reduce(0, +)
        let snowYesterday = recentHistory.first?.snowfallAmountCM ?? 0
        let snowTwoDaysAgo = recentHistory.dropFirst().first?.snowfallAmountCM ?? 0
        
        // Determine days since significant snow from ACTUAL weather data
        let daysSinceSnow: Int = {
            // Check each day in history for significant snowfall
            for (index, day) in recentHistory.prefix(7).enumerated() {
                if (day.snowfallAmountCM ?? 0) >= significantSnowCM {
                    return index + 1  // +1 because index 0 = yesterday = 1 day ago
                }
            }
            // No significant snow found in history - default to fine-grained range (not old!)
            // This is safer than assuming old snow
            return fineGrainedMaxDays - 1  // Stay in fine-grained range when uncertain
        }()
        
        let hadRecentSnow = recentSnowfall >= significantSnowCM
        let hadSnowYesterday = snowYesterday >= lightSnowCM
        let hadSignificantSnowYesterday = snowYesterday >= significantSnowCM
        
        var reasonKeys: [String] = []
        var reasonParams: [[String: String]] = []
        var confidence: AssessmentConfidence = .medium
        let group: SnowType
        
        // Key conditions
        let isCurrentlyWet = currentTemp >= wetSnowTempThreshold
        let willBeWet = hoursAboveZero >= 3 || avgTempNext6 >= wetSnowTempThreshold
        let isMoist = currentTemp >= moistSnowBoundary && currentTemp < wetSnowTempThreshold
        let isVeryCold = currentTemp <= veryColdBoundary
        let isCold = currentTemp <= coldSnowBoundary
        let isHighHumidity = humidity >= highHumidityThreshold
        
        // Check if refrozen conditions apply
        // CRITICAL: Only frozen corn if was WET and now frozen, AND no new snow cover
        let isRefrozen: Bool = {
            guard let meltDays = daysSinceLastMelt else { return false }
            guard meltDays <= meltRelevanceWindowDays else { return false }
            guard !hadRecentSnow else { return false }  // New snow covers old surface
            guard currentTemp < freezingPoint else { return false }
            guard wasYesterdayWet || meltDays == 1 else { return false }  // Must have been wet
            return true
        }()
        
        // DECISION TREE - Following Swix 5-group classification strictly
        // Group 1: New/falling snow → hard wax
        // Group 2: Fine-grained (intermediate) → hard wax
        // Group 3: Old grained (final stage) → hard wax
        // Group 4: Wet snow → klister
        // Group 5: Frozen/refrozen → klister
        
        // PRIORITY 1: Active/imminent snowfall → Group 1
        if snowImminent || heavySnowImminent {
            if currentTemp >= moistSnowBoundary {
                group = .moistNewFallen
                reasonKeys.append("Snow_Reason_NewSnow_Imminent_Moist")
                reasonParams.append(["temp": Self.format(currentTemp)])
            } else {
                group = .newFallen
                reasonKeys.append("Snow_Reason_NewSnow_Imminent_Dry")
                reasonParams.append(["temp": Self.format(currentTemp)])
            }
            confidence = heavySnowImminent ? .high : .medium
        }
        // PRIORITY 2: Currently wet → Group 4
        else if isCurrentlyWet || willBeWet {
            if currentTemp >= slushTempThreshold || (hoursAboveZero >= 5 && avgTempNext6 >= 1.0) {
                group = .veryWetCorn
                reasonKeys.append("Snow_Reason_VeryWet_Forecast")
                reasonParams.append(["temp": Self.format(currentTemp), "hours": "\(hoursAboveZero)"])
                confidence = .high
            } else if wasYesterdayWet || (daysSinceLastMelt ?? 99) <= 1 {
                group = .wetCorn
                reasonKeys.append("Snow_Reason_WetCorn_Warming")
                reasonParams.append(["temp": Self.format(currentTemp)])
                confidence = .high
            } else {
                group = .transformedMoistFine
                reasonKeys.append("Snow_Reason_TransformedMoist_Warming")
                reasonParams.append(["temp": Self.format(currentTemp)])
                confidence = .medium
            }
        }
        // PRIORITY 3: Significant snow yesterday → Group 1
        else if hadSignificantSnowYesterday {
            if isMoist {
                group = .moistNewFallen
                reasonKeys.append("Snow_Reason_NewSnow_Moist")
                reasonParams.append(["snow": Self.format(snowYesterday)])
            } else {
                group = .newFallen
                reasonKeys.append("Snow_Reason_NewSnow_Dry")
                reasonParams.append(["snow": Self.format(snowYesterday)])
            }
            confidence = .high
        }
        // PRIORITY 4: Light snow yesterday → Group 1/2 boundary
        else if hadSnowYesterday {
            if isMoist {
                group = .moistFineGrained
                reasonKeys.append("Snow_Reason_LightSnow_Moist")
                reasonParams.append([:])
            } else {
                group = .fineGrained
                reasonKeys.append("Snow_Reason_LightSnow_Refreshed")
                reasonParams.append([:])
            }
            confidence = .high
        }
        // PRIORITY 5: Recent snow (2-3 days) → Group 2
        else if hadRecentSnow && daysSinceSnow <= 3 {
            if isMoist {
                group = .moistFineGrained
                reasonKeys.append("Snow_Reason_FineGrained_MoistConditions")
                reasonParams.append([:])
            } else {
                group = .fineGrained
                reasonKeys.append("Snow_Reason_FineGrained_Recent")
                reasonParams.append(["days": "\(daysSinceSnow)"])
            }
            confidence = .high
        }
        // PRIORITY 6: Refrozen (was wet, now frozen) → Group 5
        else if isRefrozen {
            group = .frozenCorn
            reasonKeys.append("Snow_Reason_YesterdayWetNowFrozen")
            reasonParams.append(["temp": Self.format(currentTemp)])
            confidence = .high
        }
        // PRIORITY 7: Moist conditions near zero → Group 2 (moist variant)
        else if isMoist && isHighHumidity {
            group = .moistFineGrained
            reasonKeys.append("Snow_Reason_MoistFineGrained_Humidity")
            reasonParams.append(["temp": Self.format(currentTemp)])
            confidence = .medium
        }
        // PRIORITY 8: Dry snow transformation based on ACTUAL days since snow
        // Group 1 → Group 2 → Group 3 progression
        else {
            // Use actual days, not "effective age" - temperature affects CONDITIONS not age calculation
            // Cold weather keeps snow in newer state, but we track by actual days
            
            if daysSinceSnow <= 1 {
                // 0-1 days: Group 1 (new snow)
                if isMoist {
                    group = .moistNewFallen
                    reasonKeys.append("Snow_Reason_NewSnow_Moist")
                    reasonParams.append(["snow": Self.format(recentSnowfall)])
                } else {
                    group = .newFallen
                    reasonKeys.append("Snow_Reason_NewSnow_Dry")
                    reasonParams.append(["snow": Self.format(recentSnowfall)])
                }
                confidence = .high
            }
            else if daysSinceSnow <= fineGrainedMaxDays {
                // 2-4 days: Group 2 (fine-grained)
                if isMoist {
                    group = .moistFineGrained
                    reasonKeys.append("Snow_Reason_MoistFineGrained_NearZero")
                    reasonParams.append(["temp": Self.format(currentTemp)])
                } else if isCold {
                    // Cold slows transformation - still clearly fine-grained
                    group = .fineGrained
                    reasonKeys.append("Snow_Reason_FineGrained_Cold")
                    reasonParams.append(["temp": Self.format(currentTemp)])
                    confidence = .high
                } else {
                    group = .fineGrained
                    reasonKeys.append("Snow_Reason_FineGrained_DaysSinceSnow")
                    reasonParams.append(["days": "\(daysSinceSnow)"])
                }
                confidence = .medium
            }
            else {
                // 5+ days: Group 3 (old grained)
                if isMoist {
                    // Old snow getting moist - borderline conditions
                    group = .transformedMoistFine
                    reasonKeys.append("Snow_Reason_OldSnow_NearZero")
                    reasonParams.append(["temp": Self.format(currentTemp)])
                    confidence = .medium
                } else {
                    group = .oldGrained
                    reasonKeys.append("Snow_Reason_OldSnow_Dry")
                    reasonParams.append(["days": "\(daysSinceSnow)"])
                    confidence = isVeryCold ? .high : .medium
                }
            }
        }
        
        return SnowSurfaceAssessment(
            id: UUID(),
            date: currentHour.date,
            group: group,
            confidence: confidence,
            reasonKeys: reasonKeys,
            reasonParams: reasonParams,
            recentSnowCM: recentSnowfall,
            minTempC: next6Hours.map { $0.temperatureC }.min(),
            maxTempC: next6Hours.map { $0.temperatureC }.max(),
            hoursAboveZero: hoursAboveZero,
            hoursBelowMinus5: hoursBelowMinus5,
            refreezeDetected: isRefrozen,
            daysSinceLastMelt: daysSinceLastMelt,
            daysSinceSignificantSnow: daysSinceSnow,
            humidity: humidity
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

    private static func estimateSnowFromPrecip(totalMM: Double?, precipitation: Precipitation?, maxTempC: Double?) -> Double? {
        guard let totalMM, totalMM > 0 else { return nil }
        guard let precipitation else { return nil }
        
        let tempC = maxTempC ?? -5.0
        let snowRatio: Double = {
            if tempC >= 0 { return 5.0 }       // Wet, dense snow
            if tempC >= -5 { return 10.0 }     // Normal
            if tempC >= -10 { return 12.0 }    // Cold
            return 15.0                         // Very cold, fluffy
        }()
        
        switch precipitation {
        case .snow: return (totalMM * snowRatio) / 10.0
        case .mixed: return (totalMM * snowRatio * 0.5) / 10.0
        default: return nil
        }
    }

    private static func format(_ value: Double) -> String {
        let f = NumberFormatter()
        f.maximumFractionDigits = 1
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Test Shim

extension WeatherServiceClient {
    internal func test_assessPastDaily(_ pastDaily: [DailyHistorySummary]) -> [SnowSurfaceAssessment] {
        assessPastDailyWithHistory(pastDaily: pastDaily)
    }

    internal func test_assessCurrentFromHourly(_ next24: [HourlyForecastEntry]) -> SnowSurfaceAssessment? {
        assessCurrentConditions(next24: next24, recentHistory: [], historicalAssessments: [])
    }
    
    internal func test_assessCurrentWithHistory(
        next24: [HourlyForecastEntry],
        recentHistory: [DailyHistorySummary],
        historicalAssessments: [SnowSurfaceAssessment]
    ) -> SnowSurfaceAssessment? {
        assessCurrentConditions(next24: next24, recentHistory: recentHistory, historicalAssessments: historicalAssessments)
    }
}

// MARK: - SnowType Extensions

extension SnowType {
    /// Maps to Swix 5-group classification
    public var swixGroup: Int {
        switch self {
        case .newFallen, .moistNewFallen: return 1
        case .fineGrained, .moistFineGrained: return 2
        case .oldGrained: return 3
        case .wetCorn, .veryWetCorn, .transformedMoistFine: return 4
        case .frozenCorn: return 5
        }
    }
    
    /// Whether klister is typically required
    public var requiresKlister: Bool {
        switch self {
        case .newFallen, .moistNewFallen, .fineGrained, .moistFineGrained, .oldGrained:
            return false  // Hard wax
        case .transformedMoistFine:
            return false  // Soft hard wax or universal klister
        case .wetCorn, .veryWetCorn, .frozenCorn:
            return true   // Klister
        }
    }
    
    /// Localized wax guidance
    public var waxGuidance: String {
        switch self {
        case .newFallen: return String(localized: "WaxGuidance_NewFallen")
        case .moistNewFallen: return String(localized: "WaxGuidance_MoistNewFallen")
        case .fineGrained: return String(localized: "WaxGuidance_FineGrained")
        case .moistFineGrained: return String(localized: "WaxGuidance_MoistFineGrained")
        case .oldGrained: return String(localized: "WaxGuidance_OldGrained")
        case .transformedMoistFine: return String(localized: "WaxGuidance_TransformedMoistFine")
        case .wetCorn: return String(localized: "WaxGuidance_WetCorn")
        case .veryWetCorn: return String(localized: "WaxGuidance_VeryWetCorn")
        case .frozenCorn: return String(localized: "WaxGuidance_FrozenCorn")
        }
    }
}
