import Foundation
import Combine

@MainActor
final class RecommendedWaxesViewModel: ObservableObject {
    // Inputs
    @Published var effectiveGroup: SnowType = .fineGrained {
        didSet { recompute() }
    }
    @Published var weatherTempC: Int? = 0 {
        didSet { recompute() }
    }

    // Outputs
    @Published private(set) var recommended: [SwixWax] = []

    init(group: SnowType = .fineGrained, tempC: Int = 0) {
        self.effectiveGroup = group
        self.weatherTempC = tempC
        recompute()
    }

    func set(group: SnowType, tempC: Int?) {
        effectiveGroup = group
        weatherTempC = tempC
        // recompute() called by didSet
    }

    private func recompute() {
        let group = effectiveGroup
        let tempInt = weatherTempC

        recommended = swixWaxes.filter { wax in
            guard let range = tempRange(for: wax, group: group) else { return false }
            return range.min <= (tempInt) ?? 0 && (tempInt ?? 0) <= range.max
        }
    }

    private func tempRange(for wax: SwixWax, group: SnowType) -> TempRangeC? {
        return wax.ranges[group]?.first
    }
}
