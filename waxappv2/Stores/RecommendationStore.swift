import Foundation
import Combine
import SwiftUI // For Animation if needed, but stores should be UI agnostic mostly.

//struct WaxRecommendation: Identifiable, Equatable {
//    var id: String { wax.id }
//    let wax: SwixWax
//    let reason: String
//    let percentageMatch: Double
//    
//    // Equatable for SwiftUI diffing
//    static func == (lhs: WaxRecommendation, rhs: WaxRecommendation) -> Bool {
//        lhs.wax.id == rhs.wax.id && lhs.percentageMatch == rhs.percentageMatch
//    }
//}

@MainActor
final class RecommendationStore: ObservableObject {
    // Current "inputs" for recommendation
    @Published var temperature: Int = -5 {
        didSet { recompute() }
    }
    @Published var snowType: SnowType = .fineGrained {
        didSet { recompute() }
    }
    
    // User override state
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
    
    // Weather "defaults"
    private var weatherTemperature: Int?
    private var weatherSnowType: SnowType?
    
    var isOverridden: Bool {
        let tempOverridden = (weatherTemperature != nil && temperature != weatherTemperature!)
        let typeOverridden = (userSelectedSnowType != nil)
        return tempOverridden || typeOverridden
    }

    @Published private(set) var recommended: [WaxRecommendation] = []
    
    private var cancellables = Set<AnyCancellable>()
    
    init(weatherStore: WeatherStore) {
        weatherStore.$summary
            .receive(on: RunLoop.main)
            .sink { [weak self] summary in
                self?.handleWeatherUpdate(summary)
            }
            .store(in: &cancellables)
    }
    
    func resetOverrides() {
        userSelectedSnowType = nil
        if let wt = weatherTemperature {
            self.temperature = wt
        }
        if let wst = weatherSnowType {
             self.snowType = wst
        }
    }
    
    func nearestRecommendedTemperature(from current: Int) -> Int? {
        // Gather all ranges for the given snow type
        let ranges: [TempRangeC] = swixWaxes.flatMap { wax in
            wax.ranges[snowType] ?? []
        }
        guard !ranges.isEmpty else { return nil }
        
        // Find the nearest point on any range to the current temperature
        var bestTarget: Int = current
        var bestDistance: Int = Int.max
        
        for r in ranges {
            // Clamp the current temp to this range to get the nearest point on the interval
            let clamped = max(r.min, min(current, r.max))
            let distance = abs(clamped - current)
            if distance < bestDistance {
                bestDistance = distance
                bestTarget = clamped
            }
        }
        return bestTarget
    }
    
    private func handleWeatherUpdate(_ summary: WeatherAndSnowpackSummary?) {
        guard let summary else { return }
        
        // Update weather defaults
        if let firstHour = summary.weather.next24Hours.first {
            let newTemp = Int(firstHour.temperatureC)
            self.weatherTemperature = newTemp
            // Reset temp on new weather
            self.temperature = newTemp
        }
        
        if let assessment = summary.currentAssessment {
             self.weatherSnowType = assessment.group
             // Reset override on new assessment
             self.userSelectedSnowType = nil 
             self.snowType = assessment.group
        }
    }

    private func recompute() {
        var newRecommendations: [WaxRecommendation] = []
        let currentTemp = Double(temperature)
        
        for wax in swixWaxes {
            guard let range = tempRange(for: wax, group: snowType) else { continue }
            
            // Check strict containment first
            if range.min <= temperature && temperature <= range.max {
                let min = Double(range.min)
                let max = Double(range.max)
                
                let center = (min + max) / 2.0
                let distanceToCenter = abs(currentTemp - center)
                let halfWidth = (max - min) / 2.0
                
                let matchScore: Double
                if halfWidth > 0 {
                    matchScore = 1.0 - (distanceToCenter / halfWidth)
                } else {
                    matchScore = 1.0
                }
                
                newRecommendations.append(WaxRecommendation(
                    wax: wax,
                    reason: "",
                    percentageMatch: matchScore
                ))
            }
        }
        
        recommended = newRecommendations.sorted { (lhs, rhs) -> Bool in
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
