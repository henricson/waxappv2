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
                predominantPrecipitation: .snow
            )
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        #expect(results.first?.group == .group1)
    }

    @Test("Group 2: Cold, 0–1 days since snow")
    func group2_coldFewDaysNoSnow() async throws {
        let svc = await WeatherServiceClient()
        let base = Calendar.current.startOfDay(for: .now)

        // Build two days: most recent with no new snow, previously had snow (so daysSinceSnow = 1)
        let pastDaily: [DailyHistorySummary] = [
            .init(date: day(-1, from: base), temperatureMinC: -6, temperatureMaxC: -3, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil),
            .init(date: day(-2, from: base), temperatureMinC: -8, temperatureMaxC: -4, totalPrecipitationMM: 5, snowfallAmountCM: 5, predominantPrecipitation: .snow)
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        #expect(results.first?.group == .group2)
    }

    @Test("Group 3: Several cold days without snow")
    func group3_manyColdDaysNoSnow() async throws {
        let svc = await WeatherServiceClient()
        let base = Calendar.current.startOfDay(for: .now)

        // 5 days of cold, no snow. Newest first.
        let pastDaily: [DailyHistorySummary] = [
            .init(date: day(-1, from: base), temperatureMinC: -10, temperatureMaxC: -5, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil),
            .init(date: day(-2, from: base), temperatureMinC: -9, temperatureMaxC: -6, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil),
            .init(date: day(-3, from: base), temperatureMinC: -8, temperatureMaxC: -6, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil),
            .init(date: day(-4, from: base), temperatureMinC: -7, temperatureMaxC: -5, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil),
            .init(date: day(-5, from: base), temperatureMinC: -6, temperatureMaxC: -4, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: nil)
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        // The newest day is evaluated first, so it will be group2.
        // The oldest day in this list should reach daysSinceSnow >= 4, thus group3.
        #expect(results.last?.group == .group3)
    }

    @Test("Group 4: Wet day without refreeze")
    func group4_wetNoRefreeze() async throws {
        let svc = await WeatherServiceClient()
        let base = Calendar.current.startOfDay(for: .now)

        let pastDaily: [DailyHistorySummary] = [
            .init(date: day(-1, from: base), temperatureMinC: 1, temperatureMaxC: 3, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: .rain)
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        #expect(results.first?.group == .group4)
        #expect(results.first?.refreezeDetected == false)
    }

    @Test("Group 5: Wet day with nighttime refreeze")
    func group5_refreezeAfterWarm() async throws {
        let svc = await WeatherServiceClient()
        let base = Calendar.current.startOfDay(for: .now)

        // Warm during the day, then min <= -1°C (refreezeNightBelowC)
        let pastDaily: [DailyHistorySummary] = [
            .init(date: day(-1, from: base), temperatureMinC: -2, temperatureMaxC: 2, totalPrecipitationMM: 0, snowfallAmountCM: 0, predominantPrecipitation: .rain)
        ]

        let results = await svc.test_assessPastDaily(pastDaily)
        #expect(results.first?.group == .group5)
        #expect(results.first?.refreezeDetected == true)
    }

    // MARK: Current (hourly) assessment tests

    @Test("Current: Snowy now -> Group 1")
    func current_group1_snowNow() async throws {
        let svc = await WeatherServiceClient()
        let base = Date()

        let hours: [HourlyForecastEntry] = [
            .init(date: hour(0, from: base), temperatureC: -1, precipitationChance: 0.8, precipitation: .snow, relativeHumidity: 0.9),
            .init(date: hour(1, from: base), temperatureC: -1, precipitationChance: 0.6, precipitation: .snow, relativeHumidity: 0.9)
        ]

        let result = await svc.test_assessCurrentFromHourly(hours)
        #expect(result?.group == .group1)
    }

    @Test("Current: Above freezing soon -> Group 4")
    func current_group4_wetSoon() async throws {
        let svc = await WeatherServiceClient()
        let base = Date()

        let hours: [HourlyForecastEntry] = [
            .init(date: hour(0, from: base), temperatureC: -0.5, precipitationChance: 0.1, precipitation: nil, relativeHumidity: 0.6),
            .init(date: hour(1, from: base), temperatureC: 0.5, precipitationChance: 0.1, precipitation: nil, relativeHumidity: 0.6),
            .init(date: hour(2, from: base), temperatureC: 1.0, precipitationChance: 0.1, precipitation: nil, relativeHumidity: 0.6)
        ]

        let result = await svc.test_assessCurrentFromHourly(hours)
        #expect(result?.group == .group4)
    }

    @Test("Current: Cold, no snow imminent -> Group 2 or 3 depending on temp")
    func current_group2_or_3_coldNoSnow() async throws {
        let svc = await WeatherServiceClient()
        let base = Date()

        // Moderately cold -> expect Group 2
        let hours2: [HourlyForecastEntry] = [
            .init(date: hour(0, from: base), temperatureC: -3, precipitationChance: 0.0, precipitation: nil, relativeHumidity: 0.5)
        ]
        let res2 = await svc.test_assessCurrentFromHourly(hours2)
        #expect(res2?.group == .group2)

        // Very cold (<= -8) -> expect Group 3
        let hours3: [HourlyForecastEntry] = [
            .init(date: hour(0, from: base), temperatureC: -10, precipitationChance: 0.0, precipitation: nil, relativeHumidity: 0.4)
        ]
        let res3 = await svc.test_assessCurrentFromHourly(hours3)
        #expect(res3?.group == .group3)
    }
}
