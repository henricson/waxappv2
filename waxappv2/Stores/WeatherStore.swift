// `waxappv2/Stores/WeatherStore.swift`

import Foundation
import Observation
import _LocationEssentials

/// Store that manages weather data for the current location.
@MainActor
@Observable
final class WeatherStore : WeatherAnalyzer {
    var currentTemperature: Double = 0.0

    /// Monotonically increasing counter bumped after each successful fetch.
    /// This lets dependents observe "fresh weather" even when temperature is unchanged.
    var weatherRevision: UInt64 = 0
    
    private var amountOfSnowFallInMMCountsAsNewSnow: Double = 1.0
    
    private var amountOfHoursWhereNewSnowIsNewSnow: Int = 24
    
    private var amountOfHoursBeforeNewSnowIsFineGrained: Int = 72
    
    private var amountOfHoursBeforeFineGrainedIsOldSnow: Int = 168
    
    private var averageSnowfall: Double = 0.0
    
    var weatherDataPoints : [WeatherDataPointModel] = []
    
    private var locationStore : LocationStore
    
    init(locationStore : LocationStore) {
        self.locationStore = locationStore
        self.startObservingLocation()
    }
    
    /// Watches `locationStore.location` for changes and triggers a weather fetch.
    private func startObservingLocation() {
        withObservationTracking {
            // Access the property so the observation system tracks it.
            _ = locationStore.location
        } onChange: { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                // Only fetch if we have a valid location
                if self.locationStore.location != nil {
                    print("📍 Location changed, fetching weather...")
                    await self.fetchWeather()
                }
                // Re-arm: observe the next change by calling recursively.
                self.startObservingLocation()
            }
        }
    }
    
    func fetchWeather() async {
        print("🌤️ Fetching weather!")
        let weatherFactory = WeatherKitWeatherProviderFactory().makeProvider()
        guard let location = locationStore.location else {
            print("⚠️ No location available for weather fetch")
            return
        }
        
        let kirkenes = CLLocation(latitude: location.lat, longitude: location.lon)
        let now = Date()
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: now)!
        let interval = DateInterval(start: tenDaysAgo, end: now)

        do {
            let dataPoints = try await weatherFactory.data(for: kirkenes, in: interval, granularity: .hourly)
            weatherDataPoints = dataPoints
            if let lastDataPoint = weatherDataPoints.last {
                currentTemperature = lastDataPoint.averageTemperature
                weatherRevision &+= 1
                print("✅ Weather fetched! Temperature: \(currentTemperature)°C, revision: \(weatherRevision)")
            }
        } catch {
            print("❌ Failed to fetch weather data:", error)
        }
    }
    
    var currentSnowType: SnowType {
        let now = Date()
        
        // Parameters (using your existing configurable thresholds)
        let newSnowThresholdMM = amountOfSnowFallInMMCountsAsNewSnow        // 1.0 mm
        let newSnowWindowHours = amountOfHoursWhereNewSnowIsNewSnow        // 24 hours
        let fineGrainedWindowHours = amountOfHoursBeforeNewSnowIsFineGrained // 48 hours
        let oldSnowWindowHours = amountOfHoursBeforeFineGrainedIsOldSnow   // 72 hours
        
        // Temperature thresholds for moisture classification
        let freezingPoint: Double = 0.0
        let moistThreshold: Double = -2.0  // Snow becomes moist/transformed near freezing
        let wetSnowThreshold: Double = 1.0  // Clearly above freezing = wet conditions
        let veryWetThreshold: Double = 3.0  // Significantly above freezing = very wet/slushy
        
        // Calculate snowfall in different time windows
        let newSnowCutoff = Calendar.current.date(byAdding: .hour, value: -newSnowWindowHours, to: now)!
        let fineGrainedCutoff = Calendar.current.date(byAdding: .hour, value: -fineGrainedWindowHours, to: now)!
        let oldSnowCutoff = Calendar.current.date(byAdding: .hour, value: -oldSnowWindowHours, to: now)!
        
        // Sum snowfall in each window
        let recentSnowfall = weatherDataPoints
            .filter { $0.end > newSnowCutoff }
            .reduce(0.0) { $0 + $1.averageAmountOfSnow }
        
        let mediumTermSnowfall = weatherDataPoints
            .filter { $0.end > fineGrainedCutoff && $0.end <= newSnowCutoff }
            .reduce(0.0) { $0 + $1.averageAmountOfSnow }
        
        let olderSnowfall = weatherDataPoints
            .filter { $0.end > oldSnowCutoff && $0.end <= fineGrainedCutoff }
            .reduce(0.0) { $0 + $1.averageAmountOfSnow }
        
        // Check if there was a warm period followed by freeze (for frozen corn detection)
        // Look for: temperatures above freezing followed by current temp below freezing
        let hadWarmPeriod = weatherDataPoints
            .filter { $0.end > oldSnowCutoff }
            .contains { $0.averageTemperature > wetSnowThreshold }
        
        let currentTemp = currentTemperature
        let isFreezing = currentTemp < freezingPoint
        let isNearFreezing = currentTemp >= moistThreshold && currentTemp <= wetSnowThreshold
        let isWet = currentTemp > wetSnowThreshold
        let isVeryWet = currentTemp > veryWetThreshold
        
        // Group 5: Frozen/refrozen corn snow
        // Wet snow that has refrozen - requires klister
        if hadWarmPeriod && isFreezing && currentTemp < moistThreshold {
            return .frozenCorn
        }
        
        // Group 4: Wet snow conditions (above freezing)
        if isVeryWet {
            return .veryWetCorn
        }
        
        if isWet {
            return .wetCorn
        }
        
        // Group 1: New fallen snow (within newSnowWindowHours with sufficient accumulation)
        if recentSnowfall >= newSnowThresholdMM {
            // Moist new snow when near freezing
            if isNearFreezing {
                return .moistNewFallen
            }
            return .newFallen
        }
        
        // Group 2: Fine-grained (intermediate transformation)
        // Snow fell between 24-48 hours ago, or recent snow but transforming near 0°C
        let hasMediumTermSnow = mediumTermSnowfall >= newSnowThresholdMM
        let hasAnyRecentSnow = recentSnowfall > 0 || mediumTermSnowfall > 0
        
        if hasMediumTermSnow || (hasAnyRecentSnow && !weatherDataPoints.isEmpty) {
            // Transformed moist fine-grained: near/around 0°C, humid conditions
            if isNearFreezing {
                return hadWarmPeriod ? .transformedMoistFine : .moistFineGrained
            }
            return .fineGrained
        }
        
        // Group 3: Old grained snow (final transformation stage)
        // Snow is older than fineGrainedWindowHours, or no significant recent snowfall
        let hasOlderSnow = olderSnowfall >= newSnowThresholdMM
        
        if hasOlderSnow || (!hasAnyRecentSnow) {
            // Near freezing with old snow and previous warm period = transformed
            if isNearFreezing && hadWarmPeriod {
                return .transformedMoistFine
            }
            return .oldGrained
        }
        
        // Default fallback: fine-grained (safe middle ground)
        return .fineGrained
    }
}
