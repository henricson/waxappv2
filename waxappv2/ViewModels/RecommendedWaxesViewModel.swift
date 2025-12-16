import Foundation
import Combine

protocol RecommendedWaxAlgorithm {
    func recommendedWaxes(snowType: SnowType, temperature: Int) -> [SwixWax]
}

extension RecommendedWaxAlgorithm {
    func recommendedWaxes(snowType: SnowType, temperature: Int) -> [SwixWax] {
        self.recommendedWaxes(snowType: snowType, temperature: temperature)
    }
}

struct WaxRecommendation {
    let wax: SwixWax
    let reason: String
    let percentageMatch: Double
}

@MainActor
final class RecommendedWaxesViewModel: ObservableObject {
    // Inputs
    @Published var snowType: SnowType = .fineGrained {
        didSet { recompute() }
    }
    @Published var temperature: Int = 0 {
        didSet { recompute() }
    }

    // Outputs
    @Published private(set) var recommended: [WaxRecommendation] = []

    init(snowType: SnowType = .fineGrained, temperature: Int = 0) {
        self.snowType = snowType
        self.temperature = temperature
        recompute()
    }

    private func recompute() {
        var newRecommendations: [WaxRecommendation] = []
        
        for wax in swixWaxes {
            guard let range = tempRange(for: wax, group: snowType) else { continue }
            
            if range.min <= temperature && temperature <= range.max {
                let min = Double(range.min)
                let max = Double(range.max)
                let temp = Double(temperature)
                
                let center = (min + max) / 2.0
                let halfWidth = (max - min) / 2.0
                
                let percentage: Double
                if halfWidth == 0 {
                    percentage = 1.0
                } else {
                    let distance = abs(temp - center)
                    percentage = Swift.max(0.0, 1.0 - (distance / halfWidth))
                }
                
                newRecommendations.append(WaxRecommendation(
                    wax: wax,
                    reason: "",
                    percentageMatch: percentage
                ))
            }
        }
        
        recommended = newRecommendations.sorted { $0.percentageMatch > $1.percentageMatch }
    }

    private func tempRange(for wax: SwixWax, group: SnowType) -> TempRangeC? {
        return wax.ranges[group]?.first
    }
}
