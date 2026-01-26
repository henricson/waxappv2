import Foundation

struct WaxRecommendation {
    let wax: SwixWax
    let reason: String
    let percentageMatch: Double
}

@MainActor
@Observable
final class RecommendationViewModel {
    
    // MARK: - Dependencies
    
    private let waxSelectionStore: WaxSelectionStore
    
    // MARK: - User Inputs
    
    var snowType: SnowType = .fineGrained
    var temperature: Int = -5
    
    // MARK: - Computed Output
    
    var recommended: [WaxRecommendation] {
        let currentTemp = Double(temperature)
        let selectedIDs = waxSelectionStore.selectedWaxIDs
        let eligibleWaxes = swixWaxes.filter { selectedIDs.contains($0.id) }
        
        var recommendations: [WaxRecommendation] = []
        
        for wax in eligibleWaxes {
            guard let range = tempRange(for: wax, group: snowType) else { continue }
            guard range.min <= temperature && temperature <= range.max else { continue }
            
            let min = Double(range.min)
            let max = Double(range.max)
            let center = (min + max) / 2.0
            let halfWidth = (max - min) / 2.0
            let distanceToCenter = abs(currentTemp - center)
            
            let matchScore: Double = halfWidth > 0
                ? 1.0 - (distanceToCenter / halfWidth)
                : 1.0
            
            recommendations.append(WaxRecommendation(
                wax: wax,
                reason: "",
                percentageMatch: matchScore
            ))
        }
        
        return recommendations.sorted { lhs, rhs in
            if abs(lhs.percentageMatch - rhs.percentageMatch) > 0.01 {
                return lhs.percentageMatch > rhs.percentageMatch
            }
            
            let widthL = tempRange(for: lhs.wax, group: snowType).map { $0.max - $0.min } ?? 0
            let widthR = tempRange(for: rhs.wax, group: snowType).map { $0.max - $0.min } ?? 0
            return widthL < widthR
        }
    }
    
    // MARK: - Init
    
    init(
        snowType: SnowType = .fineGrained,
        temperature: Int = -5,
        waxSelectionStore: WaxSelectionStore
    ) {
        self.snowType = snowType
        self.temperature = temperature
        self.waxSelectionStore = waxSelectionStore
    }
    
    // MARK: - Private
    
    private func tempRange(for wax: SwixWax, group: SnowType) -> TempRangeC? {
        wax.ranges[group]?.first
    }
}
