//
//  RecommendationStore.swift
//  waxappv2
//

import Foundation
import Observation

/// Represents a wax recommendation with match scoring
struct WaxRecommendation {
    let wax: SwixWax
    let reason: String
    let percentageMatch: Double
}

/// Store that computes and manages wax recommendations.
@MainActor
@Observable
final class RecommendationStore {
    
    // MARK: - Dependencies
    
    private let weatherStore: WeatherStore
    private let waxSelectionStore: WaxSelectionStore
    
    // MARK: - Computed Properties (Reactive)
    
    /// Effective temperature for recommendations
    private var weatherKitTemperature: Int = -7
    var effectiveTemperature: Int = -7
    
    private var weatherKitSnowType: SnowType = .fineGrained
    var effectiveSnowType: SnowType = .fineGrained
    
    var isSameAsWeatherKit: Bool {
        weatherKitTemperature == effectiveTemperature && weatherKitSnowType == effectiveSnowType
    }
    
    /// Flag to prevent multiple concurrent observation registrations
    private var isObserving: Bool = false
        
    /// Computed recommendations based on current temperature, snow type, and selected waxes
    var recommended: [WaxRecommendation] {
        let currentTemp = effectiveTemperature
        let currentSnowType = effectiveSnowType
        let selectedIDs = waxSelectionStore.selectedWaxIDs
        
        let eligibleWaxes = swixWaxes.filter { selectedIDs.contains($0.id) }
        
        var recommendations: [WaxRecommendation] = []
        
        for wax in eligibleWaxes {
            guard let range = wax.ranges[currentSnowType]?.first else { continue }
            guard range.min <= currentTemp && currentTemp <= range.max else { continue }
            
            let matchScore = calculateMatchScore(
                temperature: Double(currentTemp),
                range: range
            )
            
            recommendations.append(WaxRecommendation(
                wax: wax,
                reason: "",
                percentageMatch: matchScore
            ))
        }
        
        return sortRecommendations(recommendations, snowType: currentSnowType)
    }
    
    // MARK: - Initialization
    
    init(weatherStore: WeatherStore, waxSelectionStore: WaxSelectionStore) {
        self.weatherStore = weatherStore
        self.waxSelectionStore = waxSelectionStore
        
        // Update temperature and snow type from weather store
        self.weatherKitTemperature = Int(weatherStore.currentTemperature)
        self.weatherKitSnowType = weatherStore.currentSnowType
        
        // Start observing weather store changes
        self.startObservingWeather()
    }
    
    /// Watches `weatherStore` for changes and updates recommendations accordingly.
    /// Uses a flag to prevent multiple concurrent observation registrations.
    private func startObservingWeather() {
        guard !isObserving else { return }
        isObserving = true
        
        withObservationTracking {
            _ = self.weatherStore.currentTemperature
            _ = self.weatherStore.currentSnowType
            _ = self.weatherStore.weatherRevision
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isObserving = false
                self.handleWeatherChange()
                self.startObservingWeather()
            }
        }
    }

    private func handleWeatherChange() {
        #if DEBUG
        print("🎯 Weather data changed, updating recommendations...")
        #endif
        
        self.weatherKitTemperature = Int(self.weatherStore.currentTemperature)
        self.effectiveTemperature = self.weatherKitTemperature
        self.weatherKitSnowType = self.weatherStore.currentSnowType
        self.effectiveSnowType = self.weatherKitSnowType
        
        #if DEBUG
        print("🎯 Updated temp: \(self.weatherKitTemperature)°C, snow type: \(self.effectiveSnowType)")
        #endif
    }
    
    // MARK: - Public Methods
    
    /// Finds the nearest recommended temperature from the current temperature
    func nearestRecommendedTemperature(from current: Int) -> Int? {
        let selectedIDs = waxSelectionStore.selectedWaxIDs
        let eligibleWaxes = swixWaxes.filter { selectedIDs.contains($0.id) }
        let ranges = eligibleWaxes.flatMap { $0.ranges[effectiveSnowType] ?? [] }
        
        guard !ranges.isEmpty else { return nil }
        
        var bestTarget = current
        var bestDistance = Int.max
        
        for range in ranges {
            let clamped = max(range.min, min(current, range.max))
            let distance = abs(clamped - current)
            
            if distance < bestDistance {
                bestDistance = distance
                bestTarget = clamped
            }
        }
        
        return bestTarget
    }
    
    // MARK: - Private Methods
    
    private func calculateMatchScore(temperature: Double, range: TempRangeC) -> Double {
        let min = Double(range.min)
        let max = Double(range.max)
        let center = (min + max) / 2.0
        let halfWidth = (max - min) / 2.0
        
        guard halfWidth > 0 else { return 1.0 }
        
        let distanceToCenter = abs(temperature - center)
        return 1.0 - (distanceToCenter / halfWidth)
    }
    
    private func sortRecommendations(_ recommendations: [WaxRecommendation], snowType: SnowType) -> [WaxRecommendation] {
        recommendations.sorted { lhs, rhs in
            if abs(lhs.percentageMatch - rhs.percentageMatch) > 0.01 {
                return lhs.percentageMatch > rhs.percentageMatch
            }
            
            let widthL = lhs.wax.ranges[snowType]?.first.map { $0.max - $0.min } ?? 0
            let widthR = rhs.wax.ranges[snowType]?.first.map { $0.max - $0.min } ?? 0
            return widthL < widthR
        }
    }
}
