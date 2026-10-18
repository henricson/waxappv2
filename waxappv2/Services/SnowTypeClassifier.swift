import Foundation

/// Pure-function classifier that determines the current snow type based on
/// temperature, precipitation history, and thermal conditions.
///
/// Based on the Swix 5-group system and snow metamorphism science.
/// Sources:
/// - Swix Wax Manual: https://swixsport.com/eu/article/wax-manual/factors-influencing-ski-waxing
/// - Sommerfeld & LaChapelle (1970): "The Classification of Snow Metamorphism"
/// - Swiss Federal Institute for Snow and Avalanche Research (SLF)
nonisolated enum SnowTypeClassifier {

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
    let recentSnowfall: Double  // Last 24h (mm)
    let mediumTermSnowfall: Double  // 24-72h ago (mm)
    let olderSnowfall: Double  // 72h-7days ago (mm)
    let recentRainfall: Double  // Last 24h (mm)
    let lastSignificantSnowDate: Date?
    let hoursSinceLastSnow: Double?

    /// Adjusted hours since snow, accounting for temperature-dependent metamorphism
    let effectiveAgingHours: Double?

    /// Lying snow depth, cm, when the provider reports it.
    let snowDepthCM: Double?
  }

  private static func analyzeSnowfall(
    dataPoints: [WeatherDataPointModel],
    currentTemperature: Double,
    now: Date
  ) -> SnowfallAnalysis {
    let significantSnowThreshold = 1.0  // mm

    let hours24Ago = now.addingTimeInterval(-24 * 3600)
    let hours72Ago = now.addingTimeInterval(-72 * 3600)
    let days7Ago = now.addingTimeInterval(-7 * 24 * 3600)

    let recentSnowfall =
      dataPoints
      .filter { $0.end > hours24Ago && $0.start <= now }
      .reduce(0.0) { $0 + $1.averageAmountOfSnow }

    let mediumTermSnowfall =
      dataPoints
      .filter { $0.end > hours72Ago && $0.end <= hours24Ago }
      .reduce(0.0) { $0 + $1.averageAmountOfSnow }

    let olderSnowfall =
      dataPoints
      .filter { $0.end > days7Ago && $0.end <= hours72Ago }
      .reduce(0.0) { $0 + $1.averageAmountOfSnow }

    let recentRainfall =
      dataPoints
      .filter { $0.end > hours24Ago && $0.start <= now }
      .reduce(0.0) { $0 + $1.averageAmountOfRain }

    let lastSnowEvent =
      dataPoints
      .filter { $0.averageAmountOfSnow >= significantSnowThreshold && $0.start <= now }
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
      recentRainfall: recentRainfall,
      lastSignificantSnowDate: lastSnowEvent?.end,
      hoursSinceLastSnow: hoursSinceLastSnow,
      effectiveAgingHours: effectiveAgingHours,
      snowDepthCM: dataPoints.compactMap(\.snowDepthCM).last
    )
  }

  /// Calculates effective aging hours by integrating the temperature-dependent
  /// metamorphism rate over the weather data points in the given range.
  ///
  /// Each point contributes its own duration (not a fixed hour), so the result
  /// is correct for daily data as well as hourly.
  private static func calculateEffectiveAging(
    from startDate: Date,
    to endDate: Date,
    dataPoints: [WeatherDataPointModel],
    currentTemperature: Double
  ) -> Double {
    let relevantPoints = dataPoints.filter {
      $0.end >= startDate && $0.start <= endDate
    }

    guard !relevantPoints.isEmpty else {
      let hours = endDate.timeIntervalSince(startDate) / 3600.0
      return hours * metamorphismRate(for: currentTemperature)
    }

    return relevantPoints.reduce(0.0) { total, point in
      let hours = max(0, point.end.timeIntervalSince(point.start) / 3600.0)
      return total + hours * metamorphismRate(for: point.averageTemperature)
    }
  }

  // MARK: - Thermal History Analysis

  struct ThermalHistory {
    let hadMeltConditions: Bool  // Was there a sustained period above 0°C?
    let currentlyAboveFreezing: Bool
    let hadRefreeze: Bool  // Melt-freeze cycle completed?
    let hoursFrozenSinceMelt: Int  // How long the pack has been refreezing
    let averageRecentTemp: Double  // Average of last 24h
    let isNearFreezing: Bool  // -2°C to +1°C (zero conditions)
    let maxRecentTemp: Double  // Max temp in last 48h
    let minRecentTemp: Double  // Min temp in last 48h
    let diurnalSwing: Double  // Temperature range (for melt-freeze detection)
  }

  private static func analyzeThermalHistory(
    dataPoints: [WeatherDataPointModel],
    currentTemperature: Double,
    now: Date
  ) -> ThermalHistory {
    let hours24Ago = now.addingTimeInterval(-24 * 3600)
    let hours48Ago = now.addingTimeInterval(-48 * 3600)
    let hours72Ago = now.addingTimeInterval(-72 * 3600)

    let recentPoints = dataPoints.filter { $0.end > hours24Ago && $0.start <= now }
    let mediumPoints = dataPoints.filter { $0.end > hours48Ago && $0.start <= now }
    let extendedPoints =
      dataPoints
      .filter { $0.end > hours72Ago && $0.start <= now }
      .sorted { $0.start < $1.start }

    // Melt needs sustained warmth: at least 4 hours above 1°C in the last 72h.
    // A brief spike above freezing doesn't transform the snowpack.
    let warmHoursCount = extendedPoints.count { $0.averageTemperature > 1.0 }
    let hadMeltConditions = warmHoursCount >= 4

    // A refreeze is a melt period followed by sub-zero hours. Detecting it
    // from the ordering — rather than from the current temperature — lets the
    // classic -1…0 °C crust case register, which is exactly when klister wins.
    // The old implementation required the current temperature to be below
    // -1 °C, so a crust sitting at -1 °C was misread as fine-grained snow.
    var hadRefreeze = false
    var hoursFrozenSinceMelt = 0
    if hadMeltConditions,
      let lastWarmIndex = extendedPoints.lastIndex(where: { $0.averageTemperature > 1.0 })
    {
      let afterWarm = extendedPoints[extendedPoints.index(after: lastWarmIndex)...]
      hoursFrozenSinceMelt = afterWarm.count { $0.averageTemperature < -0.5 }
      hadRefreeze = hoursFrozenSinceMelt >= 2
    }

    let temps = recentPoints.map(\.averageTemperature)
    let averageRecentTemp =
      temps.isEmpty ? currentTemperature : temps.reduce(0, +) / Double(temps.count)

    let mediumTemps = mediumPoints.map(\.averageTemperature)
    let maxRecentTemp = mediumTemps.max() ?? currentTemperature
    let minRecentTemp = mediumTemps.min() ?? currentTemperature

    return ThermalHistory(
      hadMeltConditions: hadMeltConditions,
      currentlyAboveFreezing: currentTemperature > 0,
      hadRefreeze: hadRefreeze,
      hoursFrozenSinceMelt: hoursFrozenSinceMelt,
      averageRecentTemp: averageRecentTemp,
      isNearFreezing: currentTemperature >= -2.0 && currentTemperature <= 1.0,
      maxRecentTemp: maxRecentTemp,
      minRecentTemp: minRecentTemp,
      diurnalSwing: maxRecentTemp - minRecentTemp
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
    snowfall: SnowfallAnalysis,
    thermal: ThermalHistory
  ) -> SnowType {

    let newSnowThresholdHours = 24.0  // Up to 24 effective hours = new snow
    let fineGrainedThresholdHours = 96.0  // 24-96 effective hours = fine-grained
    let significantSnowfall = 1.0  // mm threshold

    // ── STEP 0: Rain on snow ──
    // Liquid water in the pack dominates everything else. Rain that has since
    // refrozen gives the hardest crust there is; rain still falling gives
    // saturated snow.
    if snowfall.recentRainfall >= 2.0 {
      if currentTemp < -0.5 {
        return .frozenCorn
      }
      if currentTemp > 3.0 {
        return .veryWetCorn
      }
      return .wetCorn
    }

    // ── STEP 1: Group 5 — Frozen/Refrozen (Klister conditions) ──
    // "When wet snow freezes, it is identified as group 5, characterized
    // by large grains with frozen meltwater in between"
    //
    // A hard freeze gives a crust immediately. Just below zero it takes a
    // sustained freeze to set one — an hour or two at -0.5 °C after a thaw
    // leaves transformed, moist snow rather than frozen corn.
    if thermal.hadRefreeze {
      if currentTemp < -2.0 {
        return .frozenCorn
      }
      if currentTemp <= 0 && thermal.hoursFrozenSinceMelt >= 6 {
        return .frozenCorn
      }
    }

    // ── STEP 2: Group 4 — Wet Snow ──
    // "If snow grains in groups 1, 2, or 3 are exposed to warm weather,
    // the result is wet snow"
    if thermal.currentlyAboveFreezing {
      // Fresh snow falling into above-zero air stays new snow for a while
      // rather than becoming corn.
      if snowfall.recentSnowfall >= significantSnowfall,
        let age = snowfall.effectiveAgingHours, age < 12, currentTemp <= 1.5
      {
        return .moistNewFallen
      }
      return currentTemp > 3.0 ? .veryWetCorn : .wetCorn
    }

    // ── STEP 3: Group 1 — New/Falling Snow ──
    // "Falling and newly fallen snow characterized by relatively sharp
    // crystals, demanding relatively hard ski wax"
    if snowfall.recentSnowfall >= significantSnowfall,
      let effectiveAge = snowfall.effectiveAgingHours,
      effectiveAge < newSnowThresholdHours
    {
      return thermal.isNearFreezing ? .moistNewFallen : .newFallen
    }

    // ── STEP 4: Group 2 — Fine-Grained (Intermediate) ──
    // "An intermediate transformation stage, characterized by grains no
    // longer possible to identify as the original snow-crystal shape"
    if let effectiveAge = snowfall.effectiveAgingHours {
      if effectiveAge < fineGrainedThresholdHours {
        if thermal.isNearFreezing {
          return thermal.hadMeltConditions ? .transformedMoistFine : .moistFineGrained
        }
        return .fineGrained
      }
    } else {
      // No recorded snowfall event — check if there's any recent snow at all
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
