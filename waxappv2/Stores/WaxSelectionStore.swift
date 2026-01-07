import Foundation
import Combine

@MainActor
final class WaxSelectionStore: ObservableObject {
    private struct Persisted: Codable {
        let selectedWaxIDs: Set<String>
    }

    private let userDefaultsKey = "wax.selection.selectedWaxIDs.v1"

    /// Wax IDs (SwixWax.id) that should be shown in the app.
    @Published private(set) var selectedWaxIDs: Set<String>

    convenience init() {
        self.init(defaultSelectedWaxIDs: Set(swixWaxes.map { $0.id }))
    }

    init(defaultSelectedWaxIDs: Set<String>) {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data),
           !decoded.selectedWaxIDs.isEmpty {
            self.selectedWaxIDs = decoded.selectedWaxIDs
        } else {
            self.selectedWaxIDs = defaultSelectedWaxIDs
        }
    }

    func isSelected(_ wax: SwixWax) -> Bool {
        selectedWaxIDs.contains(wax.id)
    }

    func setSelected(_ isSelected: Bool, for wax: SwixWax) {
        if isSelected {
            selectedWaxIDs.insert(wax.id)
        } else {
            selectedWaxIDs.remove(wax.id)
        }
        persist()
    }

    func resetToAllSelected() {
        selectedWaxIDs = Set(swixWaxes.map { $0.id })
        persist()
    }

    func setAllSelected(_ isSelected: Bool, in series: WaxSeries) {
        let ids = swixWaxes
            .filter { WaxSeries(rawValue: $0.series.uppercased()) == series }
            .map { $0.id }

        if isSelected {
            selectedWaxIDs.formUnion(ids)
        } else {
            selectedWaxIDs.subtract(ids)
        }
        persist()
    }

    func selectionState(for series: WaxSeries) -> SeriesSelectionState {
        let ids = swixWaxes
            .filter { WaxSeries(rawValue: $0.series.uppercased()) == series }
            .map { $0.id }

        guard !ids.isEmpty else { return .none }

        let selectedCount = ids.reduce(into: 0) { partial, id in
            if selectedWaxIDs.contains(id) { partial += 1 }
        }

        if selectedCount == 0 { return .none }
        if selectedCount == ids.count { return .all }
        return .some
    }

    enum SeriesSelectionState {
        case none
        case some
        case all
    }

    private func persist() {
        let value = Persisted(selectedWaxIDs: selectedWaxIDs)
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
