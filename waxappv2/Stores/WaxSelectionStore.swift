//
//  WaxSelectionStore.swift
//  waxappv2
//
//  Store managing wax selection state with persistence support.
//

import Foundation
import Combine

/// Store that manages which wax products are selected for display in the app.
/// Uses PersistenceService to save/load selections across app launches.
@MainActor
final class WaxSelectionStore: ObservableObject {
    /// Internal structure for persisting selected wax IDs
    private struct Persisted: Codable {
        let selectedWaxIDs: Set<String>
    }

    /// Service for persisting selection state
    private let persistenceService: PersistenceService

    /// Wax IDs (SwixWax.id) that should be shown in the app.
    @Published private(set) var selectedWaxIDs: Set<String>

    /// Convenience initializer using default dependencies
    convenience init() {
        // Exclude VP series by default
        let defaultWaxes = swixWaxes.filter { $0.series != "VP" }
        self.init(
            defaultSelectedWaxIDs: Set(defaultWaxes.map { $0.id }),
            persistenceService: UserDefaultsPersistenceService()
        )
    }

    /// Initializes the store with custom dependencies.
    /// - Parameters:
    ///   - defaultSelectedWaxIDs: The default set of selected wax IDs to use if no persisted data exists
    ///   - persistenceService: The service to use for persistence operations
    init(defaultSelectedWaxIDs: Set<String>, persistenceService: PersistenceService = UserDefaultsPersistenceService()) {
        self.persistenceService = persistenceService
        
        // Load persisted selection or use defaults
        if let data = persistenceService.load(forKey: AppConstants.PersistenceKeys.selectedWaxIDs),
           let decoded = try? JSONDecoder().decode(Persisted.self, from: data),
           !decoded.selectedWaxIDs.isEmpty {
            self.selectedWaxIDs = decoded.selectedWaxIDs
        } else {
            self.selectedWaxIDs = defaultSelectedWaxIDs
        }
    }

    /// Checks if a specific wax is selected.
    /// - Parameter wax: The wax to check
    /// - Returns: true if the wax is selected, false otherwise
    func isSelected(_ wax: SwixWax) -> Bool {
        selectedWaxIDs.contains(wax.id)
    }

    /// Sets the selection state for a specific wax.
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

    /// Resets selection to include all available waxes.
    func resetToAllSelected() {
        selectedWaxIDs = Set(swixWaxes.map { $0.id })
        persist()
    }

    /// Sets the selection state for all waxes in a series.
    /// - Parameters:
    ///   - isSelected: Whether all waxes in the series should be selected
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

    /// Persists the current selection state using the persistence service.
    private func persist() {
        let value = Persisted(selectedWaxIDs: selectedWaxIDs)
        if let data = try? JSONEncoder().encode(value) {
            persistenceService.save(data, forKey: AppConstants.PersistenceKeys.selectedWaxIDs)
        }
    }
}
