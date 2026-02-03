//
//  waxappv2Tests.swift
//  waxappv2Tests
//
//  Created by Herman Henriksen on 18/10/2025.
//

import Foundation
import Testing
import WeatherKit
@testable import waxappv2

@Suite("WeatherService snow surface assessments")
struct WeatherServiceTests {

    // Helper to make a date offset by days/hours from a base.
    private func day(_ offset: Int, from base: Date = .now) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: base)!
    }
    private func hour(_ offset: Int, from base: Date = .now) -> Date {
        Calendar(identifier: .gregorian).date(byAdding: .hour, value: offset, to: base)!
    }

    @Test("Group 1: Recent snowfall >= threshold")
    func group1_recentSnow() async throws {
        let svc = await WeatherServiceClient()
        let base = Calendar.current.startOfDay(for: .now)

        // Newest past day first
        let pastDaily: [DailyHistorySummary] = [
            .init(
                date: day(-1, from: base),
                temperatureMinC: -5, temperatureMaxC: -2,
                totalPrecipitationMM: nil,
                snowfallAmountCM: 3.0, // >= 2 cm
                predominantPrecipitation: .snow,
                averageHumidity: 0.7
            )
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        #expect(results.first?.swixGroup == 1)
    }

    @Test("Group 2: Cold, 2–4 days since snow")
    func group2_coldFewDaysNoSnow() async throws {
        let svc = await WeatherServiceClient()
        let base = Calendar.current.startOfDay(for: .now)

        // Build days: snow on day -4, then cold days without snow (daysSinceSnow will be 2-3)
        // Algorithm processes oldest to newest: day -4 (snow) -> day -3 -> day -2 -> day -1
        // After day -4: daysSinceSnow = 0 (just snowed), then increments each day
        // Day -1 will have daysSinceSnow = 3, which falls in 2-4 range = Group 2
        let pastDaily: [DailyHistorySummary] = [
            .init(date: day(-1, from: base), temperatureMinC: -6, temperatureMaxC: -3, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.6),
            .init(date: day(-2, from: base), temperatureMinC: -7, temperatureMaxC: -4, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.6),
            .init(date: day(-3, from: base), temperatureMinC: -8, temperatureMaxC: -5, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.6),
            .init(date: day(-4, from: base), temperatureMinC: -8, temperatureMaxC: -4, totalPrecipitationMM: 5, snowfallAmountCM: 5, predominantPrecipitation: .snow, averageHumidity: 0.7)
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        // First result is day -1 (newest), which should be Group 2
        #expect(results.first?.swixGroup == 2)
    }

    @Test("Group 3: Several cold days without snow")
    func group3_manyColdDaysNoSnow() async throws {
        let svc = await WeatherServiceClient()
        let base = Calendar.current.startOfDay(for: .now)

        // Need 5+ days since snow for Group 3
        // Snow on day -7, then 6 cold days without snow
        // Algorithm processes oldest to newest, so day -1 will have daysSinceSnow = 6
        let pastDaily: [DailyHistorySummary] = [
            .init(date: day(-1, from: base), temperatureMinC: -10, temperatureMaxC: -5, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.5),
            .init(date: day(-2, from: base), temperatureMinC: -9, temperatureMaxC: -6, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.5),
            .init(date: day(-3, from: base), temperatureMinC: -8, temperatureMaxC: -6, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.5),
            .init(date: day(-4, from: base), temperatureMinC: -7, temperatureMaxC: -5, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.5),
            .init(date: day(-5, from: base), temperatureMinC: -6, temperatureMaxC: -4, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.5),
            .init(date: day(-6, from: base), temperatureMinC: -6, temperatureMaxC: -4, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.5),
            .init(date: day(-7, from: base), temperatureMinC: -8, temperatureMaxC: -4, totalPrecipitationMM: 5, snowfallAmountCM: 3, predominantPrecipitation: .snow, averageHumidity: 0.7)
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        // First result is day -1 (newest), which should be Group 3 (5+ days since snow)
        #expect(results.first?.swixGroup == 3)
    }

    @Test("Group 4: Wet day without refreeze")
    func group4_wetNoRefreeze() async throws {
        let svc = await WeatherServiceClient()
        let base = Calendar.current.startOfDay(for: .now)

        let pastDaily: [DailyHistorySummary] = [
            .init(date: day(-1, from: base), temperatureMinC: 1, temperatureMaxC: 3, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: .rain, averageHumidity: 0.8)
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        #expect(results.first?.swixGroup == 4)
        #expect(results.first?.refreezeDetected == false)
    }

    @Test("Group 5: Wet day followed by freeze")
    func group5_refreezeAfterWarm() async throws {
        let svc = await WeatherServiceClient()
        let base = Calendar.current.startOfDay(for: .now)

        // For Group 5 (frozen corn), we need:
        // 1. A previous wet day (maxC >= 0.5) to set daysSinceLastMelt
        // 2. A following cold day (avgC < 0) with no significant new snow
        // Algorithm processes oldest to newest: day -2 (wet) sets melt state, day -1 (cold) checks refreeze
        let pastDaily: [DailyHistorySummary] = [
            .init(date: day(-1, from: base), temperatureMinC: -5, temperatureMaxC: -2, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil, averageHumidity: 0.6),
            .init(date: day(-2, from: base), temperatureMinC: 0, temperatureMaxC: 3, totalPrecipitationMM: 2, snowfallAmountCM: 0, predominantPrecipitation: .rain, averageHumidity: 0.8)
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        // First result is day -1 (newest), which should be Group 5 (refrozen after melt)
        #expect(results.first?.swixGroup == 5)
        #expect(results.first?.refreezeDetected == true)
    }

    // MARK: Current (hourly) assessment tests

    @Test("Current: Snowy now -> Group 1")
    func current_group1_snowNow() async throws {
        let svc = await WeatherServiceClient()
        let base = Date()

        let hours: [HourlyForecastEntry] = [
            .init(date: hour(0, from: base), temperatureC: -1, precipitationChance: 0.8, precipitation: .snow, relativeHumidity: 0.9, windSpeedKmh: 10, cloudCover: 0.8),
            .init(date: hour(1, from: base), temperatureC: -1, precipitationChance: 0.6, precipitation: .snow, relativeHumidity: 0.9, windSpeedKmh: 10, cloudCover: 0.8)
        ]

        let result = await svc.test_assessCurrentFromHourly(hours)
        #expect(result?.swixGroup == 1)
    }

    @Test("Current: Above freezing -> Group 4")
    func current_group4_wetSoon() async throws {
        let svc = await WeatherServiceClient()
        let base = Date()

        // For Group 4, current temp must be >= wetSnowTempThreshold (0.5°C)
        // or willBeWet must be true (hoursAboveZero >= 3)
        let hours: [HourlyForecastEntry] = [
            .init(date: hour(0, from: base), temperatureC: 1.0, precipitationChance: 0.1, precipitation: nil, relativeHumidity: 0.6, windSpeedKmh: 5, cloudCover: 0.3),
            .init(date: hour(1, from: base), temperatureC: 1.5, precipitationChance: 0.1, precipitation: nil, relativeHumidity: 0.6, windSpeedKmh: 5, cloudCover: 0.3),
            .init(date: hour(2, from: base), temperatureC: 2.0, precipitationChance: 0.1, precipitation: nil, relativeHumidity: 0.6, windSpeedKmh: 5, cloudCover: 0.3)
        ]

        let result = await svc.test_assessCurrentFromHourly(hours)
        #expect(result?.swixGroup == 4)
    }

    @Test("Current: Cold, no snow imminent -> Group 2 (default without history)")
    func current_group2_or_3_coldNoSnow() async throws {
        let svc = await WeatherServiceClient()
        let base = Date()

        // Without history, daysSinceSnow defaults to fineGrainedMaxDays - 1 = 3
        // This means Group 2 (fine-grained) for cold conditions
        // Group classification is based on days since snow, not temperature alone
        let hours2: [HourlyForecastEntry] = [
            .init(date: hour(0, from: base), temperatureC: -3, precipitationChance: 0.0, precipitation: nil, relativeHumidity: 0.5, windSpeedKmh: 5, cloudCover: 0.2)
        ]
        let res2 = await svc.test_assessCurrentFromHourly(hours2)
        #expect(res2?.swixGroup == 2)

        // Even very cold temps result in Group 2 without history
        // (Group 3 requires 5+ days since snow, which needs actual history data)
        let hours3: [HourlyForecastEntry] = [
            .init(date: hour(0, from: base), temperatureC: -10, precipitationChance: 0.0, precipitation: nil, relativeHumidity: 0.4, windSpeedKmh: 5, cloudCover: 0.2)
        ]
        let res3 = await svc.test_assessCurrentFromHourly(hours3)
        #expect(res3?.swixGroup == 2) // Without history, defaults to Group 2
    }
}
