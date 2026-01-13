//
//  RecommendationStore.swift
//  waxappv2
//
//  Store managing wax recommendations based on weather and user selections.
//

import Foundation
import Combine
import SwiftUI

/// Store that computes and manages wax recommendations.
/// Observes weather and wax selection changes to provide real-time recommendations.
@MainActor
final class RecommendationStore: ObservableObject {
    // MARK: - Published Properties
    
    /// Current temperature setting for recommendations
    @Published var temperature: Int = -5 {
        didSet {
            // Mark as overridden if user changes temperature after weather is available
            if oldValue != temperature && weatherTemperature != nil {
                userOverrodeTemperature = (temperature != weatherTemperature)
            }
            recompute()
        }
    }
    
    /// Tracks if user manually changed temperature from weather default
    @Published private(set) var userOverrodeTemperature: Bool = false
    
    /// Current snow type for recommendations
    @Published var snowType: SnowType = .fineGrained {
        didSet { recompute() }
    }
    
    /// User-selected snow type override (nil means using weather default)
    @Published var userSelectedSnowType: SnowType? = nil {
        didSet {
            if let userSelection = userSelectedSnowType {
                self.snowType = userSelection
            } else {
                 if let wType = weatherSnowType {
                     self.snowType = wType
                 }
            }
        }
    }
    
    /// Computed recommended waxes
    @Published private(set) var recommended: [WaxRecommendation] = []
    
    // MARK: - Private Properties
    
    /// Weather-provided temperature (nil if not available)
    private var weatherTemperature: Int?
    
    /// Weather-provided snow type (nil if not available)
    private var weatherSnowType: SnowType?
    
    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    /// Store for wax selections
    private let waxSelectionStore: WaxSelectionStore
    
    // MARK: - Computed Properties
    
    /// Indicates if user has overridden weather defaults
    var isOverridden: Bool {
        userSelectedSnowType != nil || userOverrodeTemperature
    }
    
    /// Indicates if temperature matches weather forecast
    var isUsingWeatherTemperature: Bool {
        !userOverrodeTemperature && weatherTemperature != nil
    }
    
    /// Indicates if snow type matches weather forecast
    var isUsingWeatherSnowType: Bool {
        userSelectedSnowType == nil && weatherSnowType != nil
    }

    // MARK: - Initialization
    
    /// Initializes the recommendation store with dependencies.
    /// - Parameters:
    ///   - weatherStore: Store providing weather data
    ///   - waxSelectionStore: Store managing wax selections
    init(weatherStore: WeatherStore, waxSelectionStore: WaxSelectionStore) {
        self.waxSelectionStore = waxSelectionStore

        // Observe weather updates
        weatherStore.$summary
            .receive(on: RunLoop.main)
            .sink { [weak self] summary in
                self?.handleWeatherUpdate(summary)
            }
            .store(in: &cancellables)

        // Observe wax selection changes
        waxSelectionStore.$selectedWaxIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Resets all user overrides to weather defaults.
    func resetOverrides() {
        userSelectedSnowType = nil
        userOverrodeTemperature = false
        if let wt = weatherTemperature {
            self.temperature = wt
        }
        if let wst = weatherSnowType {
             self.snowType = wst
        }
    }
    
    /// Finds the nearest recommended temperature from the current temperature.
    /// - Parameter current: The current temperature
    /// - Returns: The nearest temperature within any eligible wax range, or nil if none available
    func nearestRecommendedTemperature(from current: Int) -> Int? {
        let ranges = collectEligibleRanges()
        guard !ranges.isEmpty else { return nil }
        
        return findNearestTemperature(to: current, in: ranges)
    }
    
    // MARK: - Private Methods - Weather Updates
    
    private func handleWeatherUpdate(_ summary: WeatherAndSnowpackSummary?) {
        guard let summary else { return }
        
        if let firstHour = summary.weather.next24Hours.first {
            let newTemp = Int(firstHour.temperatureC)
            self.weatherTemperature = newTemp
            // Only update temperature if user hasn't overridden it
            if !userOverrodeTemperature {
                self.temperature = newTemp
            }
        }
        
        if let assessment = summary.currentAssessment {
             self.weatherSnowType = assessment.group
             // Only update if user hasn't overridden snow type
             if userSelectedSnowType == nil {
                 self.snowType = assessment.group
             }
        }
    }
    
    // MARK: - Private Methods - Temperature Finding
    
    private func collectEligibleRanges() -> [TempRangeC] {
        let eligibleWaxes = swixWaxes.filter { waxSelectionStore.selectedWaxIDs.contains($0.id) }
        return eligibleWaxes.flatMap { wax in
            wax.ranges[snowType] ?? []
        }
    }
    
    private func findNearestTemperature(to current: Int, in ranges: [TempRangeC]) -> Int? {
        var bestTarget: Int = current
        var bestDistance: Int = Int.max
        
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
    
    // MARK: - Private Methods - Recommendation Computation
    
    private func recompute() {
        let currentTemp = Double(temperature)
        let eligibleWaxes = swixWaxes.filter { waxSelectionStore.selectedWaxIDs.contains($0.id) }
        
        var newRecommendations: [WaxRecommendation] = []

        for wax in eligibleWaxes {
            guard let range = tempRange(for: wax, group: snowType) else { continue }
            
            if range.min <= temperature && temperature <= range.max {
                let matchScore = calculateMatchScore(temperature: currentTemp, range: range)
                
                newRecommendations.append(WaxRecommendation(
                    wax: wax,
                    reason: "",
                    percentageMatch: matchScore
                ))
            }
        }
        
        recommended = sortRecommendations(newRecommendations)
    }
    
    private func calculateMatchScore(temperature: Double, range: TempRangeC) -> Double {
        let min = Double(range.min)
        let max = Double(range.max)
        
        let center = (min + max) / 2.0
        let distanceToCenter = abs(temperature - center)
        let halfWidth = (max - min) / 2.0
        
        if halfWidth > 0 {
            return 1.0 - (distanceToCenter / halfWidth)
        } else {
            return 1.0
        }
    }
    
    private func sortRecommendations(_ recommendations: [WaxRecommendation]) -> [WaxRecommendation] {
        recommendations.sorted { (lhs, rhs) -> Bool in
            if abs(lhs.percentageMatch - rhs.percentageMatch) > 0.01 {
                return lhs.percentageMatch > rhs.percentageMatch
            }
            
            let rangeL = tempRange(for: lhs.wax, group: snowType)!
            let widthL = rangeL.max - rangeL.min
            let rangeR = tempRange(for: rhs.wax, group: snowType)!
            let widthR = rangeR.max - rangeR.min
            return widthL < widthR
        }
    }

    private func tempRange(for wax: SwixWax, group: SnowType) -> TempRangeC? {
        return wax.ranges[group]?.first
    }
}
