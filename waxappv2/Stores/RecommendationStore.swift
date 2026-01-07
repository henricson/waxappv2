import Foundation
import Combine
import SwiftUI

/// Store managing wax recommendations based on weather and snow conditions.
/// Observes weather data and user-selected waxes to compute optimal recommendations.
@MainActor
final class RecommendationStore: ObservableObject {
    // MARK: - Published Properties
    
    /// Current temperature for recommendation calculation (°C)
    @Published var temperature: Int = -5 {
        didSet { recompute() }
    }
    
    /// Current snow type for recommendation calculation
    @Published var snowType: SnowType = .fineGrained {
        didSet { recompute() }
    }
    
    /// User-selected snow type override (nil means using weather data)
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
    
    /// Computed wax recommendations
    @Published private(set) var recommended: [WaxRecommendation] = []
    
    // MARK: - Private Properties
    
    /// Weather-derived temperature (not overridden by user)
    private var weatherTemperature: Int?
    
    /// Weather-derived snow type (not overridden by user)
    private var weatherSnowType: SnowType?
    
    private var cancellables = Set<AnyCancellable>()
    private let waxSelectionStore: WaxSelectionStore
    
    /// Whether the user has overridden weather defaults
    var isOverridden: Bool {
        let tempOverridden = (weatherTemperature != nil && temperature != weatherTemperature!)
        let typeOverridden = (userSelectedSnowType != nil)
        return tempOverridden || typeOverridden
    }

    /// Convenience initializer for production use.
    convenience init(weatherStore: WeatherStore, waxSelectionStore: WaxSelectionStore) {
        self.init(
            weatherDataProvider: weatherStore,
            waxSelectionStore: waxSelectionStore
        )
    }
    
    /// Designated initializer with dependency injection.
    /// - Parameters:
    ///   - weatherDataProvider: Provider of weather data updates
    ///   - waxSelectionStore: Store managing wax selection state
    init(
        weatherDataProvider: WeatherDataProvider,
        waxSelectionStore: WaxSelectionStore
    ) {
        self.waxSelectionStore = waxSelectionStore

        // Observe weather updates
        weatherDataProvider.summaryPublisher
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
    
    /// Resets user overrides to use weather-based values.
    func resetOverrides() {
        userSelectedSnowType = nil
        if let wt = weatherTemperature {
            self.temperature = wt
        }
        if let wst = weatherSnowType {
            self.snowType = wst
        }
    }
    
    /// Finds the nearest recommended temperature to the given temperature.
    /// Useful for guiding users to adjust temperature to get recommendations.
    /// - Parameter current: The current temperature
    /// - Returns: The nearest temperature that has recommendations, or nil if none exist
    func nearestRecommendedTemperature(from current: Int) -> Int? {
        let ranges = gatherEligibleRanges()
        guard !ranges.isEmpty else { return nil }
        
        return findNearestTemperatureInRanges(ranges, to: current)
    }
    
    // MARK: - Private Methods
    
    /// Gathers all temperature ranges for the current snow type from eligible waxes.
    /// - Returns: Array of temperature ranges
    private func gatherEligibleRanges() -> [TempRangeC] {
        let eligibleWaxes = swixWaxes.filter { waxSelectionStore.selectedWaxIDs.contains($0.id) }
        
        return eligibleWaxes.flatMap { wax in
            wax.ranges[snowType] ?? []
        }
    }
    
    /// Finds the temperature within the given ranges that is closest to the target.
    /// - Parameters:
    ///   - ranges: The temperature ranges to search
    ///   - current: The target temperature
    /// - Returns: The closest temperature within any range
    private func findNearestTemperatureInRanges(_ ranges: [TempRangeC], to current: Int) -> Int? {
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
    
    /// Handles updates from the weather data provider.
    /// - Parameter summary: The new weather summary
    private func handleWeatherUpdate(_ summary: WeatherAndSnowpackSummary?) {
        guard let summary else { return }
        
        // Update weather-derived temperature
        if let firstHour = summary.weather.next24Hours.first {
            let newTemp = Int(firstHour.temperatureC)
            self.weatherTemperature = newTemp
            self.temperature = newTemp
        }
        
        // Update weather-derived snow type
        if let assessment = summary.currentAssessment {
            self.weatherSnowType = assessment.group
            self.userSelectedSnowType = nil
            self.snowType = assessment.group
        }
    }

    /// Recomputes recommendations based on current temperature and snow type.
    private func recompute() {
        let newRecommendations = computeRecommendations()
        recommended = sortRecommendations(newRecommendations)
    }
    
    /// Computes wax recommendations for the current conditions.
    /// - Returns: Array of unsorted recommendations
    private func computeRecommendations() -> [WaxRecommendation] {
        var recommendations: [WaxRecommendation] = []
        let currentTemp = Double(temperature)

        let eligibleWaxes = swixWaxes.filter { waxSelectionStore.selectedWaxIDs.contains($0.id) }

        for wax in eligibleWaxes {
            guard let range = tempRange(for: wax, group: snowType) else { continue }
            
            // Check if temperature is within range
            if range.min <= temperature && temperature <= range.max {
                let matchScore = calculateMatchScore(
                    temperature: currentTemp,
                    rangeMin: Double(range.min),
                    rangeMax: Double(range.max)
                )
                
                recommendations.append(WaxRecommendation(
                    wax: wax,
                    reason: "",
                    percentageMatch: matchScore
                ))
            }
        }
        
        return recommendations
    }
    
    /// Calculates a match score based on how close the temperature is to the center of the range.
    /// - Parameters:
    ///   - temperature: The current temperature
    ///   - rangeMin: The minimum of the temperature range
    ///   - rangeMax: The maximum of the temperature range
    /// - Returns: A score from 0.0 to 1.0, where 1.0 is a perfect center match
    private func calculateMatchScore(temperature: Double, rangeMin: Double, rangeMax: Double) -> Double {
        let center = (rangeMin + rangeMax) / 2.0
        let distanceToCenter = abs(temperature - center)
        let halfWidth = (rangeMax - rangeMin) / 2.0
        
        if halfWidth > 0 {
            return 1.0 - (distanceToCenter / halfWidth)
        } else {
            return 1.0
        }
    }
    
    /// Sorts recommendations by match score and range width.
    /// - Parameter recommendations: The recommendations to sort
    /// - Returns: Sorted recommendations (best match first)
    private func sortRecommendations(_ recommendations: [WaxRecommendation]) -> [WaxRecommendation] {
        recommendations.sorted { (lhs, rhs) -> Bool in
            // Primary sort: by match percentage (higher is better)
            if abs(lhs.percentageMatch - rhs.percentageMatch) > 0.01 {
                return lhs.percentageMatch > rhs.percentageMatch
            }
            
            // Tie-breaker: prefer narrower ranges (more specific)
            guard let rangeL = tempRange(for: lhs.wax, group: snowType),
                  let rangeR = tempRange(for: rhs.wax, group: snowType) else {
                return false
            }
            
            let widthL = rangeL.max - rangeL.min
            let widthR = rangeR.max - rangeR.min
            return widthL < widthR
        }
    }

    /// Gets the temperature range for a wax and snow type combination.
    /// - Parameters:
    ///   - wax: The wax to get the range for
    ///   - group: The snow type
    /// - Returns: The temperature range, or nil if not applicable
    private func tempRange(for wax: SwixWax, group: SnowType) -> TempRangeC? {
        wax.ranges[group]?.first
    }
}
