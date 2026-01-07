import Foundation
import Combine

/// Store managing the selection state of wax products.
/// Handles persistence of selected wax IDs and provides methods to query and update selections.
@MainActor
final class WaxSelectionStore: ObservableObject {
    /// Internal structure for persisting selected wax IDs
    private struct Persisted: Codable {
        let selectedWaxIDs: Set<String>
    }

    private let persistenceService: PersistenceService
    private let persistenceKey: String

    /// Wax IDs (SwixWax.id) that should be shown in the app.
    @Published private(set) var selectedWaxIDs: Set<String>

    /// Convenience initializer with default dependencies.
    /// Uses UserDefaults for persistence and selects all waxes by default.
    convenience init() {
        self.init(
            defaultSelectedWaxIDs: Set(swixWaxes.map { $0.id }),
            persistenceService: UserDefaultsPersistenceService(),
            persistenceKey: AppConstants.PersistenceKeys.selectedWaxIDs
        )
    }

    /// Designated initializer with dependency injection.
    /// - Parameters:
    ///   - defaultSelectedWaxIDs: The default set of wax IDs to use if no persisted data exists
    ///   - persistenceService: The service to use for data persistence
    ///   - persistenceKey: The key to use for storing data in the persistence service
    init(
        defaultSelectedWaxIDs: Set<String>,
        persistenceService: PersistenceService = UserDefaultsPersistenceService(),
        persistenceKey: String = AppConstants.PersistenceKeys.selectedWaxIDs
    ) {
        self.persistenceService = persistenceService
        self.persistenceKey = persistenceKey
        
        // Try to load persisted selection
        if let data = persistenceService.load(forKey: persistenceKey),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data),
           !decoded.selectedWaxIDs.isEmpty {
            self.selectedWaxIDs = decoded.selectedWaxIDs
        } else {
            self.selectedWaxIDs = defaultSelectedWaxIDs
        }
    }

    // MARK: - Query Methods
    
    /// Checks if a specific wax is selected.
    /// - Parameter wax: The wax to check
    /// - Returns: true if the wax is selected, false otherwise
    func isSelected(_ wax: SwixWax) -> Bool {
        selectedWaxIDs.contains(wax.id)
    }

    /// Gets the selection state for a wax series.
    /// - Parameter series: The wax series to check
    /// - Returns: The selection state (none, some, or all)
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
    
    // MARK: - Mutation Methods

    /// Updates the selection state for a specific wax.
    /// - Parameters:
    ///   - isSelected: Whether the wax should be selected
    ///   - wax: The wax to update
    func setSelected(_ isSelected: Bool, for wax: SwixWax) {
        if isSelected {
            selectedWaxIDs.insert(wax.id)
        } else {
            selectedWaxIDs.remove(wax.id)
        }
        persist()
    }

    /// Resets the selection to include all available waxes.
    func resetToAllSelected() {
        selectedWaxIDs = Set(swixWaxes.map { $0.id })
        persist()
    }

    /// Updates the selection state for all waxes in a series.
    /// - Parameters:
    ///   - isSelected: Whether the waxes should be selected
    ///   - series: The wax series to update
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
    
    // MARK: - Private Methods

    /// Persists the current selection state to storage.
    private func persist() {
        let value = Persisted(selectedWaxIDs: selectedWaxIDs)
        if let data = try? JSONEncoder().encode(value) {
            persistenceService.save(data, forKey: persistenceKey)
        }
    }
}
