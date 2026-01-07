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
final class RecommendationViewModel: ObservableObject {
    // Inputs
    @Published var snowType: SnowType = .fineGrained {
        didSet { recompute() }
    }
    @Published var temperature: Int = -5 {
        didSet { recompute() }
    }

    // Outputs
    @Published private(set) var recommended: [WaxRecommendation] = []

    private let waxSelectionStore: WaxSelectionStore
    private var cancellables = Set<AnyCancellable>()

    init(
        snowType: SnowType = .fineGrained,
        temperature: Int = 0,
        waxSelectionStore: WaxSelectionStore
    ) {
        self.snowType = snowType
        self.temperature = temperature
        self.waxSelectionStore = waxSelectionStore

        waxSelectionStore.$selectedWaxIDs
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recompute()
            }
            .store(in: &cancellables)

        recompute()
    }

    private func recompute() {
        var newRecommendations: [WaxRecommendation] = []
        let currentTemp = Double(temperature)

        let eligibleWaxes = swixWaxes.filter { waxSelectionStore.selectedWaxIDs.contains($0.id) }

        for wax in eligibleWaxes {
            guard let range = tempRange(for: wax, group: snowType) else { continue }

            // Check strict containment first
            if range.min <= temperature && temperature <= range.max {
                let min = Double(range.min)
                let max = Double(range.max)

                // Calculate the "ideal" center of this wax's range
                let center = (min + max) / 2.0

                // Calculate absolute distance from current temp to the center
                let distanceToCenter = abs(currentTemp - center)

                // We want to normalize this for sorting purposes.
                // A "perfect" match has distance 0.
                // We can use the distance directly for sorting (ascending),
                // or convert to a "score" (descending).

                // Let's create a score where 100% is dead center.
                // We use the half-width to determine how "far" out we are relative to the wax's tolerance.
                let halfWidth = (max - min) / 2.0

                let matchScore: Double
                if halfWidth > 0 {
                    // 1.0 = center, 0.0 = at the very edge of the range
                    matchScore = 1.0 - (distanceToCenter / halfWidth)
                } else {
                    // Range is a single point (min == max) and we matched it
                    matchScore = 1.0
                }

                newRecommendations.append(WaxRecommendation(
                    wax: wax,
                    reason: "",
                    percentageMatch: matchScore
                ))
            }
        }

        // SORT PRIORITY:
        // 1. Highest Match Score (Closer to center relative to its own range width)
        // 2. Tie-breaker: If scores are very close, prefer the wax with the narrower range (more specific)?
        //    Or just strictly by score.

        recommended = newRecommendations.sorted { (lhs, rhs) -> Bool in
            // If the match percentages are significantly different, use that
            if abs(lhs.percentageMatch - rhs.percentageMatch) > 0.01 {
                return lhs.percentageMatch > rhs.percentageMatch
            }

            // TIE BREAKER:
            // If two waxes are equally "centered" (e.g. both perfect matches),
            // usually the one with the narrower range is the "better" specific choice.
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
