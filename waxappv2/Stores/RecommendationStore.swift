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
        didSet { recompute() }
    }
    
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
        let tempOverridden = (weatherTemperature != nil && temperature != weatherTemperature!)
        let typeOverridden = (userSelectedSnowType != nil)
        return tempOverridden || typeOverridden
    }

    // MARK: - Initialization

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
        if let wt = weatherTemperature {
            self.temperature = wt
        }
        if let wst = weatherSnowType {
             self.snowType = wst
        }
    }
    
    /// Finds the nearest recommended temperature from the current temperature.
    /// This helps users find the closest valid wax option when no exact match exists.
    /// - Parameter current: The current temperature
    /// - Returns: The nearest temperature within any eligible wax range, or nil if none available
    func nearestRecommendedTemperature(from current: Int) -> Int? {
        let ranges = collectEligibleRanges()
        guard !ranges.isEmpty else { return nil }
        
        return findNearestTemperature(to: current, in: ranges)
    }
    
    // MARK: - Private Methods - Weather Updates
    
    /// Handles weather summary updates.
    /// - Parameter summary: The weather summary, or nil if not available
    private func handleWeatherUpdate(_ summary: WeatherAndSnowpackSummary?) {
        guard let summary else { return }
        
        // Update temperature from weather data
        if let firstHour = summary.weather.next24Hours.first {
            let newTemp = Int(firstHour.temperatureC)
            self.weatherTemperature = newTemp
            self.temperature = newTemp
        }
        
        // Update snow type from assessment
        if let assessment = summary.currentAssessment {
             self.weatherSnowType = assessment.group
             // Reset override when new assessment arrives
             self.userSelectedSnowType = nil
             self.snowType = assessment.group
        }
    }
    
    // MARK: - Private Methods - Temperature Finding
    
    /// Collects all eligible temperature ranges for the current snow type.
    /// - Returns: Array of temperature ranges from selected waxes
    private func collectEligibleRanges() -> [TempRangeC] {
        let eligibleWaxes = swixWaxes.filter { waxSelectionStore.selectedWaxIDs.contains($0.id) }
        
        return eligibleWaxes.flatMap { wax in
            wax.ranges[snowType] ?? []
        }
    }
    
    /// Finds the nearest temperature to a target within a set of ranges.
    /// - Parameters:
    ///   - current: The target temperature
    ///   - ranges: The ranges to search within
    /// - Returns: The nearest temperature, or nil if ranges are empty
    private func findNearestTemperature(to current: Int, in ranges: [TempRangeC]) -> Int? {
        var bestTarget: Int = current
        var bestDistance: Int = Int.max
        
        for range in ranges {
            // Clamp the current temp to this range to get the nearest point on the interval
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
    // MARK: - Private Methods - Recommendation Computation
    
    /// Recomputes wax recommendations based on current temperature and snow type.
    private func recompute() {
        let currentTemp = Double(temperature)
        let eligibleWaxes = swixWaxes.filter { waxSelectionStore.selectedWaxIDs.contains($0.id) }
        
        var newRecommendations: [WaxRecommendation] = []

        for wax in eligibleWaxes {
            guard let range = tempRange(for: wax, group: snowType) else { continue }
            
            // Check if temperature is within this wax's range
            if range.min <= temperature && temperature <= range.max {
                let matchScore = calculateMatchScore(
                    temperature: currentTemp,
                    range: range
                )
                
                newRecommendations.append(WaxRecommendation(
                    wax: wax,
                    reason: "",
                    percentageMatch: matchScore
                ))
            }
        }
        
        // Sort recommendations by match score and range width
        recommended = sortRecommendations(newRecommendations)
    }
    
    /// Calculates the match score for a wax based on temperature.
    /// Score is highest at the center of the range and decreases toward edges.
    /// - Parameters:
    ///   - temperature: The current temperature
    ///   - range: The wax's temperature range
    /// - Returns: A match score between 0.0 and 1.0
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
    
    /// Sorts recommendations by match score and range width.
    /// - Parameter recommendations: The recommendations to sort
    /// - Returns: Sorted recommendations (highest match first, narrower ranges preferred)
    private func sortRecommendations(_ recommendations: [WaxRecommendation]) -> [WaxRecommendation] {
        recommendations.sorted { (lhs, rhs) -> Bool in
            // First sort by match score (higher is better)
            if abs(lhs.percentageMatch - rhs.percentageMatch) > 0.01 {
                return lhs.percentageMatch > rhs.percentageMatch
            }
            
            // For equal match scores, prefer narrower ranges
            let rangeL = tempRange(for: lhs.wax, group: snowType)!
            let widthL = rangeL.max - rangeL.min
            let rangeR = tempRange(for: rhs.wax, group: snowType)!
            let widthR = rangeR.max - rangeR.min
            return widthL < widthR
        }
    }

    /// Gets the temperature range for a wax and snow type.
    /// - Parameters:
    ///   - wax: The wax to check
    ///   - group: The snow type
    /// - Returns: The temperature range, or nil if not applicable
    private func tempRange(for wax: SwixWax, group: SnowType) -> TempRangeC? {
        return wax.ranges[group]?.first
    }
}
