import Foundation
import Testing

@testable import waxappv2

@Suite("SnowTypeClassifier")
struct SnowTypeClassifierTests {

    // MARK: - Helpers

    /// Creates hourly data points over a time range with uniform temperature and snowfall.
    private func makeDataPoints(
        hours: Int,
        endingAt now: Date = Date(),
        temperature: Double,
        snowPerHour: Double = 0.0,
        rainPerHour: Double = 0.0
    ) -> [WeatherDataPointModel] {
        (0..<hours).reversed().map { hoursAgo in
            let end = now.addingTimeInterval(-Double(hoursAgo) * 3600)
            let start = end.addingTimeInterval(-3600)
            return WeatherDataPointModel(
                start: start,
                end: end,
                averageAmountOfSnow: snowPerHour,
                averageAmountOfRain: rainPerHour,
                averageTemperature: temperature
            )
        }
    }

    /// Creates a melt-freeze weather history: warm hours followed by cold hours.
    private func makeMeltFreezeDataPoints(
        warmHours: Int,
        warmTemp: Double,
        coldHours: Int,
        coldTemp: Double,
        endingAt now: Date = Date()
    ) -> [WeatherDataPointModel] {
        let totalHours = warmHours + coldHours
        return (0..<totalHours).reversed().map { hoursAgo in
            let end = now.addingTimeInterval(-Double(hoursAgo) * 3600)
            let start = end.addingTimeInterval(-3600)
            let temp = hoursAgo >= coldHours ? warmTemp : coldTemp
            return WeatherDataPointModel(
                start: start,
                end: end,
                averageAmountOfSnow: 0,
                averageAmountOfRain: 0,
                averageTemperature: temp
            )
        }
    }

    // MARK: - Group 5: Frozen/Refrozen

    @Test("Melt-freeze cycle with hard freeze returns frozen corn")
    func meltFreeze_hardFreeze_frozenCorn() {
        let now = Date()
        let points = makeMeltFreezeDataPoints(
            warmHours: 24, warmTemp: 3.0,
            coldHours: 24, coldTemp: -5.0,
            endingAt: now
        )
        let result = SnowTypeClassifier.classify(
            currentTemperature: -5.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .frozenCorn)
    }

    @Test("Melt-freeze cycle with moderate freeze returns frozen corn")
    func meltFreeze_moderateFreeze_frozenCorn() {
        let now = Date()
        let points = makeMeltFreezeDataPoints(
            warmHours: 12, warmTemp: 2.0,
            coldHours: 12, coldTemp: -2.0,
            endingAt: now
        )
        let result = SnowTypeClassifier.classify(
            currentTemperature: -2.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .frozenCorn)
    }

    // MARK: - Group 4: Wet Snow

    @Test("Above freezing returns wet corn")
    func aboveFreezing_wetCorn() {
        let now = Date()
        let points = makeDataPoints(hours: 48, endingAt: now, temperature: 2.0)
        let result = SnowTypeClassifier.classify(
            currentTemperature: 2.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .wetCorn)
    }

    @Test("Well above freezing returns very wet corn")
    func wellAboveFreezing_veryWetCorn() {
        let now = Date()
        let points = makeDataPoints(hours: 48, endingAt: now, temperature: 5.0)
        let result = SnowTypeClassifier.classify(
            currentTemperature: 5.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .veryWetCorn)
    }

    // MARK: - Group 1: New/Falling Snow

    @Test("Recent heavy snowfall in cold conditions returns new fallen")
    func recentSnow_cold_newFallen() {
        let now = Date()
        let points = makeDataPoints(
            hours: 12, endingAt: now,
            temperature: -10.0, snowPerHour: 2.0
        )
        let result = SnowTypeClassifier.classify(
            currentTemperature: -10.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .newFallen)
    }

    @Test("Recent snowfall near freezing returns moist new fallen")
    func recentSnow_nearFreezing_moistNewFallen() {
        let now = Date()
        let points = makeDataPoints(
            hours: 12, endingAt: now,
            temperature: -1.0, snowPerHour: 3.0
        )
        let result = SnowTypeClassifier.classify(
            currentTemperature: -1.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .moistNewFallen)
    }

    // MARK: - Group 2: Fine-Grained

    @Test("Snow from 2 days ago in cold conditions returns fine-grained")
    func mediumAgeSnow_cold_fineGrained() {
        let now = Date()
        // Snow fell 48 hours ago, cold and dry since then
        var points = makeDataPoints(hours: 72, endingAt: now, temperature: -8.0)
        // Add snowfall only around the 48h mark
        let snowStart = now.addingTimeInterval(-50 * 3600)
        let snowEnd = now.addingTimeInterval(-46 * 3600)
        for i in 0..<points.count {
            if points[i].end >= snowStart && points[i].end <= snowEnd {
                points[i] = WeatherDataPointModel(
                    start: points[i].start,
                    end: points[i].end,
                    averageAmountOfSnow: 3.0,
                    averageAmountOfRain: 0,
                    averageTemperature: -8.0
                )
            }
        }
        let result = SnowTypeClassifier.classify(
            currentTemperature: -8.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .fineGrained)
    }

    @Test("Medium-age snow near freezing without melt returns moist fine-grained")
    func mediumAgeSnow_nearFreezing_moistFineGrained() {
        let now = Date()
        // Snow fell 36 hours ago, near freezing since
        var points = makeDataPoints(hours: 48, endingAt: now, temperature: -1.0)
        let snowStart = now.addingTimeInterval(-38 * 3600)
        let snowEnd = now.addingTimeInterval(-34 * 3600)
        for i in 0..<points.count {
            if points[i].end >= snowStart && points[i].end <= snowEnd {
                points[i] = WeatherDataPointModel(
                    start: points[i].start,
                    end: points[i].end,
                    averageAmountOfSnow: 2.0,
                    averageAmountOfRain: 0,
                    averageTemperature: -1.0
                )
            }
        }
        let result = SnowTypeClassifier.classify(
            currentTemperature: -1.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .moistFineGrained)
    }

    // MARK: - Group 3: Old Snow

    @Test("No data points and cold returns old grained")
    func noData_cold_oldGrained() {
        let result = SnowTypeClassifier.classify(
            currentTemperature: -8.0,
            weatherDataPoints: [],
            now: Date()
        )
        #expect(result == .oldGrained)
    }

    @Test("No recent snowfall in cold conditions returns old grained")
    func noSnowfall_cold_oldGrained() {
        let now = Date()
        let points = makeDataPoints(hours: 120, endingAt: now, temperature: -10.0)
        let result = SnowTypeClassifier.classify(
            currentTemperature: -10.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .oldGrained)
    }

    // MARK: - Metamorphism Rate

    @Test("Metamorphism rate at 0°C is 1.0")
    func metamorphismRate_atFreezing() {
        let rate = SnowTypeClassifier.metamorphismRate(for: 0.0)
        #expect(rate == 1.0)
    }

    @Test("Metamorphism rate above freezing is 1.0")
    func metamorphismRate_aboveFreezing() {
        let rate = SnowTypeClassifier.metamorphismRate(for: 5.0)
        #expect(rate == 1.0)
    }

    @Test("Metamorphism rate at -5°C is approximately 0.5")
    func metamorphismRate_atMinus5() {
        let rate = SnowTypeClassifier.metamorphismRate(for: -5.0)
        #expect(abs(rate - 0.5) < 0.01)
    }

    @Test("Metamorphism rate at -10°C is approximately 0.25")
    func metamorphismRate_atMinus10() {
        let rate = SnowTypeClassifier.metamorphismRate(for: -10.0)
        #expect(abs(rate - 0.25) < 0.01)
    }

    @Test("Metamorphism rate decreases with colder temperature")
    func metamorphismRate_decreasesWithCold() {
        let rate5 = SnowTypeClassifier.metamorphismRate(for: -5.0)
        let rate10 = SnowTypeClassifier.metamorphismRate(for: -10.0)
        let rate20 = SnowTypeClassifier.metamorphismRate(for: -20.0)
        #expect(rate5 > rate10)
        #expect(rate10 > rate20)
    }

    // MARK: - Edge Cases

    @Test("Near-freezing old snow with melt conditions returns transformed moist fine")
    func nearFreezing_withMelt_transformedMoistFine() {
        let now = Date()
        // 72 hours of data, some warm periods but currently near freezing
        var points = makeDataPoints(hours: 72, endingAt: now, temperature: -1.0)
        // Add some warm hours in the middle (enough for melt conditions: >= 4 hours above 1°C)
        for i in 20..<30 {
            let idx = points.count - 1 - i
            guard idx >= 0 else { continue }
            points[idx] = WeatherDataPointModel(
                start: points[idx].start,
                end: points[idx].end,
                averageAmountOfSnow: 0,
                averageAmountOfRain: 0,
                averageTemperature: 2.0
            )
        }
        let result = SnowTypeClassifier.classify(
            currentTemperature: -1.0,
            weatherDataPoints: points,
            now: now
        )
        #expect(result == .transformedMoistFine)
    }
}
