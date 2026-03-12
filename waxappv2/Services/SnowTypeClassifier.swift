import Foundation

/// Pure-function classifier that determines the current snow type based on
/// temperature, precipitation history, and thermal conditions.
///
/// Based on the Swix 5-group system and snow metamorphism science.
/// Sources:
/// - Swix Wax Manual: https://swixsport.com/us/article/wax-manual/factors-influencing-ski-waxing
/// - Sommerfeld & LaChapelle (1970): "The Classification of Snow Metamorphism"
/// - Swiss Federal Institute for Snow and Avalanche Research (SLF)
enum SnowTypeClassifier {

    // MARK: - Public API

    /// Classifies the current snow type from weather observations.
    /// - Parameters:
    ///   - currentTemperature: The most recent temperature in Celsius.
    ///   - weatherDataPoints: Hourly weather history (up to ~10 days).
    ///   - now: The reference time (defaults to `Date()`; pass explicitly for testing).
    /// - Returns: The classified `SnowType`.
    static func classify(
        currentTemperature: Double,
        weatherDataPoints: [WeatherDataPointModel],
        now: Date = Date()
    ) -> SnowType {
        let rate = metamorphismRate(for: currentTemperature)
        let snowfall = analyzeSnowfall(
            dataPoints: weatherDataPoints,
            currentTemperature: currentTemperature,
            now: now
        )
        let thermal = analyzeThermalHistory(
            dataPoints: weatherDataPoints,
            currentTemperature: currentTemperature,
            now: now
        )
        return decide(
            currentTemp: currentTemperature,
            metamorphismRate: rate,
            snowfall: snowfall,
            thermal: thermal
        )
    }

    // MARK: - Metamorphism Rate

    /// Returns a multiplier [0...1] for how fast snow transforms at the given temperature.
    ///
    /// Metamorphism is exponentially faster near freezing:
    /// - At 0°C: rate = 1.0 (baseline, very fast)
    /// - At -5°C: rate ≈ 0.5
    /// - At -10°C: rate ≈ 0.25
    /// - At -20°C: rate ≈ 0.06
    ///
    /// Reference: US Army Corps of Engineers Snowmelt documentation
    static func metamorphismRate(for temperature: Double) -> Double {
        if temperature >= 0 { return 1.0 }
        return pow(0.5, abs(temperature) / 5.0)
    }

    // MARK: - Snowfall Analysis

    struct SnowfallAnalysis {
        let recentSnowfall: Double        // Last 24h (mm)
        let mediumTermSnowfall: Double     // 24-72h ago (mm)
        let olderSnowfall: Double          // 72h-7days ago (mm)
        let lastSignificantSnowDate: Date?
        let hoursSinceLastSnow: Double?

        /// Adjusted hours since snow, accounting for temperature-dependent metamorphism
        var effectiveAgingHours: Double?
    }

    private static func analyzeSnowfall(
        dataPoints: [WeatherDataPointModel],
        currentTemperature: Double,
        now: Date
    ) -> SnowfallAnalysis {
        let calendar = Calendar.current
        let significantSnowThreshold = 1.0 // mm

        // Time windows
        let hours24Ago =
            calendar.date(byAdding: .hour, value: -24, to: now)
            ?? now.addingTimeInterval(-24 * 3600)
        let hours72Ago =
            calendar.date(byAdding: .hour, value: -72, to: now)
            ?? now.addingTimeInterval(-72 * 3600)
        let days7Ago =
            calendar.date(byAdding: .day, value: -7, to: now)
            ?? now.addingTimeInterval(-7 * 24 * 3600)

        // Calculate snowfall in each window
        let recentSnowfall = dataPoints
            .filter { $0.end > hours24Ago }
            .reduce(0.0) { $0 + $1.averageAmountOfSnow }

        let mediumTermSnowfall = dataPoints
            .filter { $0.end > hours72Ago && $0.end <= hours24Ago }
            .reduce(0.0) { $0 + $1.averageAmountOfSnow }

        let olderSnowfall = dataPoints
            .filter { $0.end > days7Ago && $0.end <= hours72Ago }
            .reduce(0.0) { $0 + $1.averageAmountOfSnow }

        // Find last significant snowfall event
        let lastSnowEvent = dataPoints
            .filter { $0.averageAmountOfSnow >= significantSnowThreshold }
            .max(by: { $0.end < $1.end })

        var hoursSinceLastSnow: Double?
        var effectiveAgingHours: Double?

        if let lastSnow = lastSnowEvent {
            hoursSinceLastSnow = now.timeIntervalSince(lastSnow.end) / 3600.0

            effectiveAgingHours = calculateEffectiveAging(
                from: lastSnow.end,
                to: now,
                dataPoints: dataPoints,
                currentTemperature: currentTemperature
            )
        }

        return SnowfallAnalysis(
            recentSnowfall: recentSnowfall,
            mediumTermSnowfall: mediumTermSnowfall,
            olderSnowfall: olderSnowfall,
            lastSignificantSnowDate: lastSnowEvent?.end,
            hoursSinceLastSnow: hoursSinceLastSnow,
            effectiveAgingHours: effectiveAgingHours
        )
    }

    /// Calculates effective aging hours by integrating temperature-dependent metamorphism rate
    /// over the weather data points in the given range.
    private static func calculateEffectiveAging(
        from startDate: Date,
        to endDate: Date,
        dataPoints: [WeatherDataPointModel],
        currentTemperature: Double
    ) -> Double {
        let relevantPoints = dataPoints.filter {
            $0.end >= startDate && $0.end <= endDate
        }

        if relevantPoints.isEmpty {
            // If no data points, estimate based on current temperature
            let hours = endDate.timeIntervalSince(startDate) / 3600.0
            let rate = metamorphismRate(for: currentTemperature)
            return hours * rate
        }

        // Each hourly data point contributes based on the metamorphism rate at that temperature
        return relevantPoints.reduce(0.0) { total, point in
            total + metamorphismRate(for: point.averageTemperature)
        }
    }

    // MARK: - Thermal History Analysis

    struct ThermalHistory {
        let hadMeltConditions: Bool       // Was there a sustained period above 0°C?
        let currentlyAboveFreezing: Bool
        let hadFreezingAfterMelt: Bool    // Melt-freeze cycle occurred?
        let averageRecentTemp: Double     // Average of last 24h
        let isNearFreezing: Bool          // -2°C to +1°C (zero conditions)
        let maxRecentTemp: Double         // Max temp in last 48h
        let minRecentTemp: Double         // Min temp in last 48h
        let diurnalSwing: Double          // Temperature range (for melt-freeze detection)
    }

    private static func analyzeThermalHistory(
        dataPoints: [WeatherDataPointModel],
        currentTemperature: Double,
        now: Date
    ) -> ThermalHistory {
        let calendar = Calendar.current
        let hours24Ago =
            calendar.date(byAdding: .hour, value: -24, to: now)
            ?? now.addingTimeInterval(-24 * 3600)
        let hours48Ago =
            calendar.date(byAdding: .hour, value: -48, to: now)
            ?? now.addingTimeInterval(-48 * 3600)
        let hours72Ago =
            calendar.date(byAdding: .hour, value: -72, to: now)
            ?? now.addingTimeInterval(-72 * 3600)

        let recentPoints = dataPoints.filter { $0.end > hours24Ago }
        let mediumPoints = dataPoints.filter { $0.end > hours48Ago }
        let extendedPoints = dataPoints.filter { $0.end > hours72Ago }

        // Check for melt conditions (above freezing).
        // Require sustained warmth: at least 4 hours above 1°C in the last 72h.
        // A brief spike above freezing doesn't necessarily transform the snowpack.
        let warmHoursCount = extendedPoints.filter { $0.averageTemperature > 1.0 }.count
        let hadMeltConditions = warmHoursCount >= 4
        let currentlyAboveFreezing = currentTemperature > 0

        // Check for melt-freeze cycle: was above 0, now below 0
        let hadFreezingAfterMelt = hadMeltConditions && currentTemperature < -1.0

        // Temperature statistics
        let temps = recentPoints.map { $0.averageTemperature }
        let averageRecentTemp =
            temps.isEmpty ? currentTemperature : temps.reduce(0, +) / Double(temps.count)

        let mediumTemps = mediumPoints.map { $0.averageTemperature }
        let maxRecentTemp = mediumTemps.max() ?? currentTemperature
        let minRecentTemp = mediumTemps.min() ?? currentTemperature
        let diurnalSwing = maxRecentTemp - minRecentTemp

        // "Zero conditions" in ski waxing terminology: around freezing point
        let isNearFreezing = currentTemperature >= -2.0 && currentTemperature <= 1.0

        return ThermalHistory(
            hadMeltConditions: hadMeltConditions,
            currentlyAboveFreezing: currentlyAboveFreezing,
            hadFreezingAfterMelt: hadFreezingAfterMelt,
            averageRecentTemp: averageRecentTemp,
            isNearFreezing: isNearFreezing,
            maxRecentTemp: maxRecentTemp,
            minRecentTemp: minRecentTemp,
            diurnalSwing: diurnalSwing
        )
    }

    // MARK: - Decision Tree
    //
    // Follows the Swix 5-Group System:
    //   Group 1: New/Falling Snow  → .newFallen, .moistNewFallen
    //   Group 2: Fine-Grained      → .fineGrained, .moistFineGrained, .transformedMoistFine
    //   Group 3: Old Snow           → .oldGrained
    //   Group 4: Wet Snow           → .wetCorn, .veryWetCorn
    //   Group 5: Frozen/Refrozen    → .frozenCorn

    private static func decide(
        currentTemp: Double,
        metamorphismRate: Double,
        snowfall: SnowfallAnalysis,
        thermal: ThermalHistory
    ) -> SnowType {

        let newSnowThresholdHours = 24.0     // Up to 24 effective hours = new snow
        let fineGrainedThresholdHours = 96.0 // 24-96 effective hours = fine-grained
        let significantSnowfall = 1.0        // mm threshold

        // ── STEP 1: Group 5 — Frozen/Refrozen (Klister conditions) ──
        // "When wet snow freezes, it is identified as group 5, characterized
        // by large grains with frozen meltwater in between"

        if thermal.hadMeltConditions && thermal.hadFreezingAfterMelt {
            if currentTemp < -3.0 {
                return .frozenCorn       // Hard frozen — very icy
            } else if currentTemp < -1.0 {
                return .frozenCorn       // Frozen but not as hard
            }
            // If currently warming up again, fall through to wet snow check
        }

        // ── STEP 2: Group 4 — Wet Snow ──
        // "If snow grains in groups 1, 2, or 3 are exposed to warm weather,
        // the result is wet snow"

        if thermal.currentlyAboveFreezing {
            if currentTemp > 3.0 {
                return .veryWetCorn      // Very wet, slushy conditions
            } else {
                return .wetCorn          // Moderately wet
            }
        }

        // ── STEP 3: Group 1 — New/Falling Snow ──
        // "Falling and newly fallen snow characterized by relatively sharp
        // crystals, demanding relatively hard ski wax"

        let hasRecentSignificantSnow = snowfall.recentSnowfall >= significantSnowfall

        if hasRecentSignificantSnow {
            if let effectiveAge = snowfall.effectiveAgingHours,
               effectiveAge < newSnowThresholdHours
            {
                if thermal.isNearFreezing {
                    // "Falling or newly fallen snow around zero usually calls
                    // for a soft type of hard wax" — moist new snow
                    return .moistNewFallen
                }
                return .newFallen
            }
        }

        // ── STEP 4: Group 2 — Fine-Grained (Intermediate) ──
        // "An intermediate transformation stage, characterized by grains no
        // longer possible to identify as the original snow-crystal shape"

        if let effectiveAge = snowfall.effectiveAgingHours {
            if effectiveAge < fineGrainedThresholdHours {
                if thermal.isNearFreezing {
                    if thermal.hadMeltConditions {
                        return .transformedMoistFine
                    }
                    return .moistFineGrained
                }
                return .fineGrained
            }
        } else {
            // No recorded snowfall — check if there's any recent snow at all
            let totalRecentSnow = snowfall.recentSnowfall + snowfall.mediumTermSnowfall
            if totalRecentSnow >= significantSnowfall {
                if thermal.isNearFreezing {
                    return thermal.hadMeltConditions ? .transformedMoistFine : .moistFineGrained
                }
                return .fineGrained
            }
        }

        // ── STEP 5: Group 3 — Old Snow (default) ──
        // "The final stage of transformation. Uniform, rounded, bonded grains
        // characterize the snow surface"

        if thermal.isNearFreezing && thermal.hadMeltConditions {
            return .transformedMoistFine
        }

        return .oldGrained
    }
}
