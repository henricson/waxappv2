//
//  RecommendationStore.swift
//  waxappv2
//

import Foundation
import Observation

/// Store that computes and manages wax recommendations.
@MainActor
@Observable
final class RecommendationStore {
    
    // MARK: - Dependencies
    
    private let weatherStore: WeatherStore
    private let waxSelectionStore: WaxSelectionStore
    
    // MARK: - User Input State
    
    /// User-overridden temperature (nil = use weather)
    var userTemperature: Int? = nil
    
    /// User-overridden snow type (nil = use weather)
    var userSnowType: SnowType? = nil
    
    // MARK: - Computed Properties (Reactive)
    
    /// Effective temperature for recommendations
    var temperature: Int {
        userTemperature ?? weatherStore.temperature ?? -5
    }
    
    /// Effective snow type for recommendations
    var snowType: SnowType {
        userSnowType ?? weatherStore.currentAssessment?.group ?? .fineGrained
    }
    
    /// Whether user has overridden any weather defaults
    var isOverridden: Bool {
        userTemperature != nil || userSnowType != nil
    }
    
    /// Whether using weather-provided temperature
    var isUsingWeatherTemperature: Bool {
        userTemperature == nil && weatherStore.temperature != nil
    }
    
    /// Whether using weather-provided snow type
    var isUsingWeatherSnowType: Bool {
        userSnowType == nil && weatherStore.currentAssessment != nil
    }
    
    /// Computed recommendations based on current temperature, snow type, and selected waxes
    var recommended: [WaxRecommendation] {
        let currentTemp = temperature
        let currentSnowType = snowType
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
    }
    
    // MARK: - Public Methods
    
    /// Resets all user overrides to weather defaults
    func resetOverrides() {
        userTemperature = nil
        userSnowType = nil
    }
    
    /// Sets user temperature override
    func setTemperature(_ temp: Int) {
        userTemperature = temp
    }
    
    /// Sets user snow type override
    func setSnowType(_ type: SnowType) {
        userSnowType = type
    }
    
    /// Finds the nearest recommended temperature from the current temperature
    func nearestRecommendedTemperature(from current: Int) -> Int? {
        let selectedIDs = waxSelectionStore.selectedWaxIDs
        let eligibleWaxes = swixWaxes.filter { selectedIDs.contains($0.id) }
        let ranges = eligibleWaxes.flatMap { $0.ranges[snowType] ?? [] }
        
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
