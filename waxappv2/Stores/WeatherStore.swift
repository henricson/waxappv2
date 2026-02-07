// `waxappv2/Stores/WeatherStore.swift`

import Foundation
import Observation
import _LocationEssentials

/// Store that manages weather data for the current location.
@MainActor
@Observable
final class WeatherStore: WeatherAnalyzer {
  var currentTemperature: Double = -7.0

  /// Monotonically increasing counter bumped after each successful fetch.
  var weatherRevision: UInt64 = 0

  var weatherDataPoints: [WeatherDataPointModel] = []

  /// Error state for UI feedback
  var fetchError: Error?
  var isFetching: Bool = false

  private var locationStore: LocationStore

  /// Observation tracking is a one-shot mechanism. We track whether we're
  /// actively observing to avoid re-registering while a callback is in flight.
  private var isObserving: Bool = false

  init(locationStore: LocationStore) {
    self.locationStore = locationStore
    self.startObservingLocation()
  }

  /// Watches `locationStore.location` for changes and triggers a weather fetch.
  /// Uses a flag to prevent multiple concurrent observation registrations.
  private func startObservingLocation() {
    guard !isObserving else { return }
    isObserving = true

    withObservationTracking {
      _ = self.locationStore.location
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.isObserving = false

        if self.locationStore.location != nil {
          #if DEBUG
            print("📍 Location changed, fetching weather...")
          #endif
          await self.fetchWeather()
        }
        self.startObservingLocation()
      }
    }
  }

  func fetchWeather() async {
    guard !isFetching else { return }
    isFetching = true
    fetchError = nil
    defer { isFetching = false }

    #if DEBUG
      print("🌤️ Fetching weather!")
    #endif

    let weatherFactory = WeatherKitWeatherProviderFactory().makeProvider()
    guard let location = locationStore.location else {
      #if DEBUG
        print("⚠️ No location available for weather fetch")
      #endif
      return
    }

    let clLocation = CLLocation(latitude: location.lat, longitude: location.lon)
    let now = Date()
    guard let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: now) else {
      #if DEBUG
        print("⚠️ Failed to calculate date range")
      #endif
      return
    }
    let interval = DateInterval(start: tenDaysAgo, end: now)

    do {
      let dataPoints = try await weatherFactory.data(
        for: clLocation, in: interval, granularity: .hourly)
      weatherDataPoints = dataPoints
      if let lastDataPoint = weatherDataPoints.last {
        currentTemperature = lastDataPoint.averageTemperature
        weatherRevision &+= 1
        #if DEBUG
          print(
            "✅ Weather fetched! Temperature: \(currentTemperature)°C, revision: \(weatherRevision)")
        #endif
      }
    } catch {
      fetchError = error
      #if DEBUG
        print("❌ Failed to fetch weather data:", error)
      #endif
    }
  }

  // MARK: - Snow Type Classification
  // Based on Swix 5-group system and snow metamorphism science
  // Sources:
  // - Swix Wax Manual: https://swixsport.com/us/article/wax-manual/factors-influencing-ski-waxing
  // - Sommerfeld & LaChapelle (1970): "The Classification of Snow Metamorphism"
  // - Swiss Federal Institute for Snow and Avalanche Research (SLF)

  var currentSnowType: SnowType {
    let now = Date()
    let currentTemp = currentTemperature

    // STEP 1: Calculate time windows based on temperature
    // Key insight: Metamorphism rate depends heavily on temperature
    // - Near 0°C: Very fast transformation (hours)
    // - Around -5°C: Moderate transformation (1-2 days)
    // - Below -10°C: Slow transformation (3-7+ days)
    // - Below -20°C: Very slow transformation (weeks)

    let metamorphismRate = calculateMetamorphismRate(temperature: currentTemp)

    // STEP 2: Analyze recent weather history
    let snowfallAnalysis = analyzeSnowfall(now: now)
    let thermalHistory = analyzeThermalHistory(now: now)

    // STEP 3: Decision tree following Swix 5-group system
    return classifySnowType(
      currentTemp: currentTemp,
      metamorphismRate: metamorphismRate,
      snowfall: snowfallAnalysis,
      thermal: thermalHistory
    )
  }

  // MARK: - Metamorphism Rate Calculation

  /// Returns a multiplier for how fast snow transforms at given temperature
  /// Based on: "The closer the pack temperature is to 0°C, the faster metamorphism will occur"
  /// Reference: US Army Corps of Engineers Snowmelt documentation
  private func calculateMetamorphismRate(temperature: Double) -> Double {
    // Metamorphism is exponentially faster near freezing
    // At 0°C: rate = 1.0 (baseline, very fast)
    // At -5°C: rate ≈ 0.5
    // At -10°C: rate ≈ 0.25
    // At -20°C: rate ≈ 0.06

    if temperature >= 0 {
      return 1.0  // Maximum rate at/above freezing
    }

    // Exponential decay with temperature
    // Halving roughly every 5°C below zero
    return pow(0.5, abs(temperature) / 5.0)
  }

  /// Converts base hours to effective hours based on metamorphism rate
  private func effectiveTransformationHours(baseHours: Double, rate: Double) -> Double {
    guard rate > 0 else { return .infinity }
    return baseHours / rate
  }

  // MARK: - Snowfall Analysis

  struct SnowfallAnalysis {
    let recentSnowfall: Double  // Last 24h (mm)
    let mediumTermSnowfall: Double  // 24-72h ago (mm)
    let olderSnowfall: Double  // 72h-7days ago (mm)
    let lastSignificantSnowDate: Date?
    let hoursSinceLastSnow: Double?

    /// Adjusted hours since snow, accounting for temperature-dependent metamorphism
    var effectiveAgingHours: Double?
  }

  private func analyzeSnowfall(now: Date) -> SnowfallAnalysis {
    let calendar = Calendar.current
    let significantSnowThreshold = 1.0  // mm

    // Time windows - use safe date arithmetic with fallbacks
    let hours24Ago =
      calendar.date(byAdding: .hour, value: -24, to: now) ?? now.addingTimeInterval(-24 * 3600)
    let hours72Ago =
      calendar.date(byAdding: .hour, value: -72, to: now) ?? now.addingTimeInterval(-72 * 3600)
    let days7Ago =
      calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-7 * 24 * 3600)

    // Calculate snowfall in each window
    let recentSnowfall =
      weatherDataPoints
      .filter { $0.end > hours24Ago }
      .reduce(0.0) { $0 + $1.averageAmountOfSnow }

    let mediumTermSnowfall =
      weatherDataPoints
      .filter { $0.end > hours72Ago && $0.end <= hours24Ago }
      .reduce(0.0) { $0 + $1.averageAmountOfSnow }

    let olderSnowfall =
      weatherDataPoints
      .filter { $0.end > days7Ago && $0.end <= hours72Ago }
      .reduce(0.0) { $0 + $1.averageAmountOfSnow }

    // Find last significant snowfall event
    let lastSnowEvent =
      weatherDataPoints
      .filter { $0.averageAmountOfSnow >= significantSnowThreshold }
      .max(by: { $0.end < $1.end })

    var hoursSinceLastSnow: Double?
    var effectiveAgingHours: Double?

    if let lastSnow = lastSnowEvent {
      let actualHours = now.timeIntervalSince(lastSnow.end) / 3600.0
      hoursSinceLastSnow = actualHours

      // Calculate effective aging by integrating metamorphism rate over time
      effectiveAgingHours = calculateEffectiveAging(
        from: lastSnow.end,
        to: now
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
  private func calculateEffectiveAging(from startDate: Date, to endDate: Date) -> Double {
    var effectiveHours = 0.0

    // Get data points in the range
    let relevantPoints = weatherDataPoints.filter {
      $0.end >= startDate && $0.end <= endDate
    }

    for point in relevantPoints {
      let rate = calculateMetamorphismRate(temperature: point.averageTemperature)
      // Each hour contributes based on the metamorphism rate at that temperature
      effectiveHours += rate  // Assuming hourly data points
    }

    // If no data points, estimate based on current temperature
    if relevantPoints.isEmpty {
      let hours = endDate.timeIntervalSince(startDate) / 3600.0
      let rate = calculateMetamorphismRate(temperature: currentTemperature)
      effectiveHours = hours * rate
    }

    return effectiveHours
  }

  // MARK: - Thermal History Analysis

  struct ThermalHistory {
    let hadMeltConditions: Bool  // Was there a period above 0°C?
    let currentlyAboveFreezing: Bool
    let hadFreezingAfterMelt: Bool  // Melt-freeze cycle occurred?
    let averageRecentTemp: Double  // Average of last 24h
    let isNearFreezing: Bool  // -2°C to +1°C (zero conditions)
    let maxRecentTemp: Double  // Max temp in last 48h
    let minRecentTemp: Double  // Min temp in last 48h
    let diurnalSwing: Double  // Temperature range (for melt-freeze detection)
  }

  private func analyzeThermalHistory(now: Date) -> ThermalHistory {
    let calendar = Calendar.current
    // Safe date arithmetic with fallbacks
    let hours24Ago =
      calendar.date(byAdding: .hour, value: -24, to: now) ?? now.addingTimeInterval(-24 * 3600)
    let hours48Ago =
      calendar.date(byAdding: .hour, value: -48, to: now) ?? now.addingTimeInterval(-48 * 3600)
    let hours72Ago =
      calendar.date(byAdding: .hour, value: -72, to: now) ?? now.addingTimeInterval(-72 * 3600)

    let recentPoints = weatherDataPoints.filter { $0.end > hours24Ago }
    let mediumPoints = weatherDataPoints.filter { $0.end > hours48Ago }
    let extendedPoints = weatherDataPoints.filter { $0.end > hours72Ago }

    // Check for melt conditions (above freezing)
    let hadMeltConditions = extendedPoints.contains { $0.averageTemperature > 0.5 }
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

  // MARK: - Snow Type Classification Decision Tree

  private func classifySnowType(
    currentTemp: Double,
    metamorphismRate: Double,
    snowfall: SnowfallAnalysis,
    thermal: ThermalHistory
  ) -> SnowType {

    // Thresholds for effective aging (at 0°C baseline)
    // These get adjusted by the metamorphism rate
    let newSnowThresholdHours = 24.0  // Up to 24 effective hours = new snow
    let fineGrainedThresholdHours = 96.0  // 24-96 effective hours = fine-grained
    // Beyond 96 effective hours = old snow

    let significantSnowfall = 1.0  // mm threshold

    // ═══════════════════════════════════════════════════════════════════
    // DECISION TREE - Following Swix 5-Group System
    // ═══════════════════════════════════════════════════════════════════

    // ┌─────────────────────────────────────────────────────────────────┐
    // │ STEP 1: Check for Group 5 - Frozen/Refrozen (Klister conditions)│
    // └─────────────────────────────────────────────────────────────────┘
    // "When wet snow freezes, it is identified as group 5, characterized
    // by large grains with frozen meltwater in between"

    if thermal.hadMeltConditions && thermal.hadFreezingAfterMelt {
      // Melt-freeze cycle has occurred
      if currentTemp < -3.0 {
        // Hard frozen - very icy
        return .frozenCorn
      } else if currentTemp < -1.0 {
        // Frozen but not as hard
        return .frozenCorn
      }
      // If currently warming up again, fall through to wet snow check
    }

    // ┌─────────────────────────────────────────────────────────────────┐
    // │ STEP 2: Check for Group 4 - Wet Snow                           │
    // └─────────────────────────────────────────────────────────────────┘
    // "If snow grains in groups 1, 2, or 3 are exposed to warm weather,
    // the result is wet snow"

    if thermal.currentlyAboveFreezing {
      // Above freezing = wet conditions
      if currentTemp > 3.0 {
        // Very wet, slushy conditions
        return .veryWetCorn
      } else {
        // Moderately wet
        return .wetCorn
      }
    }

    // ┌─────────────────────────────────────────────────────────────────┐
    // │ STEP 3: Check for Group 1 - New/Falling Snow                   │
    // └─────────────────────────────────────────────────────────────────┘
    // "Falling and newly fallen snow characterized by relatively sharp
    // crystals, demanding relatively hard ski wax"

    let hasRecentSignificantSnow = snowfall.recentSnowfall >= significantSnowfall

    if hasRecentSignificantSnow {
      // Recent snowfall within 24 hours
      if let effectiveAge = snowfall.effectiveAgingHours,
        effectiveAge < newSnowThresholdHours
      {

        // Check moisture content based on temperature
        if thermal.isNearFreezing {
          // "Falling or newly fallen snow around zero usually calls
          // for a soft type of hard wax" - moist new snow
          return .moistNewFallen
        }
        return .newFallen
      }
    }

    // ┌─────────────────────────────────────────────────────────────────┐
    // │ STEP 4: Check for Group 2 - Fine-Grained (Intermediate)        │
    // └─────────────────────────────────────────────────────────────────┘
    // "An intermediate transformation stage, characterized by grains no
    // longer possible to identify as the original snow-crystal shape"

    if let effectiveAge = snowfall.effectiveAgingHours {
      if effectiveAge < fineGrainedThresholdHours {
        // Still in fine-grained stage
        if thermal.isNearFreezing {
          if thermal.hadMeltConditions {
            // Has been through some warming - transformed moist
            return .transformedMoistFine
          }
          return .moistFineGrained
        }
        return .fineGrained
      }
    } else {
      // No recorded snowfall - check if there's any recent snow at all
      let totalRecentSnow = snowfall.recentSnowfall + snowfall.mediumTermSnowfall
      if totalRecentSnow >= significantSnowfall {
        if thermal.isNearFreezing {
          return thermal.hadMeltConditions ? .transformedMoistFine : .moistFineGrained
        }
        return .fineGrained
      }
    }

    // ┌─────────────────────────────────────────────────────────────────┐
    // │ STEP 5: Default to Group 3 - Old Snow                          │
    // └─────────────────────────────────────────────────────────────────┘
    // "The final stage of transformation. Uniform, rounded, bonded grains
    // characterize the snow surface"

    // If we reach here:
    // - No recent significant snowfall, OR
    // - Snow has aged beyond fine-grained stage

    // Check for special near-freezing old snow conditions
    if thermal.isNearFreezing && thermal.hadMeltConditions {
      return .transformedMoistFine
    }

    return .oldGrained
  }
}
