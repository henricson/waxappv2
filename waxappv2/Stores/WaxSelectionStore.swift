//
//  WaxSelectionStore.swift
//  waxappv2
//
//  Store managing which wax series and products the user wants to see.
//

import Foundation
import Observation

/// Which wax lines the app shows.
///
/// The user picks **series** (Swix V-line, Swix Top Speed, Rode klister…) —
/// that is the unit shown in onboarding and in Settings. Power users can
/// additionally hide individual products from a series; those overrides live
/// in `hiddenProductIDs`.
@MainActor
@Observable
final class WaxSelectionStore {

  // MARK: - Persistence shape

  private struct Persisted: Codable {
    var selectedSeriesIDs: Set<String>
    var hiddenProductIDs: Set<String>
  }

  /// Pre-1.1 shape: a flat set of bare Swix product codes ("V05", "KX30"…).
  private struct LegacyPersisted: Codable {
    let selectedWaxIDs: Set<String>
  }

  // MARK: - State

  private let persistenceService: PersistenceService

  private(set) var selectedSeriesIDs: Set<String>
  private(set) var hiddenProductIDs: Set<String>

  /// True when the user has never completed the current onboarding.
  private(set) var needsOnboarding: Bool

  // MARK: - Init

  convenience init() {
    self.init(persistenceService: UserDefaultsPersistenceService())
  }

  init(
    defaultSeriesIDs: Set<String> = WaxCatalog.defaultSeriesIDs,
    persistenceService: PersistenceService? = nil
  ) {
    let service = persistenceService ?? UserDefaultsPersistenceService()
    self.persistenceService = service

    if let data = service.load(forKey: AppConstants.PersistenceKeys.waxSelection),
      let decoded = try? JSONDecoder().decode(Persisted.self, from: data),
      !decoded.selectedSeriesIDs.isEmpty
    {
      self.selectedSeriesIDs = decoded.selectedSeriesIDs
      self.hiddenProductIDs = decoded.hiddenProductIDs
      self.needsOnboarding = false
      return
    }

    // Migrate a pre-1.1 install: derive the series the user had visible, and
    // keep any individual products they had switched off.
    if let legacyData = service.load(forKey: AppConstants.PersistenceKeys.legacySelectedWaxIDs),
      let legacy = try? JSONDecoder().decode(LegacyPersisted.self, from: legacyData),
      !legacy.selectedWaxIDs.isEmpty
    {
      let migratedIDs = Set(legacy.selectedWaxIDs.map { "\(WaxBrand.swix.rawValue).\($0)" })
      let migratedProducts = WaxCatalog.all.filter { migratedIDs.contains($0.id) }
      let series = Set(migratedProducts.map(\.seriesID))

      // Products that belong to a kept series but were individually turned off.
      let hidden = Set(
        WaxCatalog.all
          .filter { series.contains($0.seriesID) && !migratedIDs.contains($0.id) }
          .map(\.id)
      )

      self.selectedSeriesIDs = series.isEmpty ? defaultSeriesIDs : series
      self.hiddenProductIDs = hidden
      // Upgraders should still see the new onboarding — it introduces gliders
      // and the second brand, neither of which existed in their old install.
      self.needsOnboarding = true
      self.persist()
      return
    }

    self.selectedSeriesIDs = defaultSeriesIDs
    self.hiddenProductIDs = []
    self.needsOnboarding = true
  }

  // MARK: - Derived

  /// Every product the user has chosen to see.
  var visibleProducts: [WaxProduct] {
    WaxCatalog.all.filter {
      selectedSeriesIDs.contains($0.seriesID) && !hiddenProductIDs.contains($0.id)
    }
  }

  func visibleProducts(in domain: WaxDomain) -> [WaxProduct] {
    visibleProducts.filter { $0.domain == domain }
  }

  /// Series the user has enabled, in catalogue order.
  var selectedSeries: [WaxSeries] {
    WaxCatalog.series.filter { selectedSeriesIDs.contains($0.id) }
  }

  func hasAnySeries(in domain: WaxDomain) -> Bool {
    selectedSeries.contains { $0.domain == domain }
  }

  var selectedBrands: Set<WaxBrand> {
    Set(selectedSeries.map(\.brand))
  }

  // MARK: - Series selection

  func isSelected(series: WaxSeries) -> Bool {
    selectedSeriesIDs.contains(series.id)
  }

  func setSelected(_ isSelected: Bool, series: WaxSeries) {
    if isSelected {
      selectedSeriesIDs.insert(series.id)
    } else {
      selectedSeriesIDs.remove(series.id)
    }
    persist()
  }

  func toggle(series: WaxSeries) {
    setSelected(!isSelected(series: series), series: series)
  }

  func setSelected(_ isSelected: Bool, brand: WaxBrand) {
    let ids = WaxCatalog.series.filter { $0.brand == brand }.map(\.id)
    if isSelected {
      selectedSeriesIDs.formUnion(ids)
    } else {
      selectedSeriesIDs.subtract(ids)
    }
    persist()
  }

  // MARK: - Product overrides

  func isSelected(_ product: WaxProduct) -> Bool {
    selectedSeriesIDs.contains(product.seriesID) && !hiddenProductIDs.contains(product.id)
  }

  func setSelected(_ isSelected: Bool, for product: WaxProduct) {
    if isSelected {
      hiddenProductIDs.remove(product.id)
      // Turning a product on implies its series is on.
      selectedSeriesIDs.insert(product.seriesID)
    } else {
      hiddenProductIDs.insert(product.id)
    }
    persist()
  }

  func setAllSelected(_ isSelected: Bool, inSeries seriesID: String) {
    let ids = WaxCatalog.products(inSeries: seriesID).map(\.id)
    if isSelected {
      selectedSeriesIDs.insert(seriesID)
      hiddenProductIDs.subtract(ids)
    } else {
      hiddenProductIDs.formUnion(ids)
    }
    persist()
  }

  func selectionState(forSeries seriesID: String) -> SeriesSelectionState {
    let products = WaxCatalog.products(inSeries: seriesID)
    guard !products.isEmpty, selectedSeriesIDs.contains(seriesID) else { return .none }

    let selectedCount = products.count { !hiddenProductIDs.contains($0.id) }
    if selectedCount == 0 { return .none }
    if selectedCount == products.count { return .all }
    return .some
  }

  // MARK: - Lifecycle

  /// Forces onboarding to run again. Used by demo mode when capturing the
  /// onboarding screenshots on a simulator that has already been through it.
  func resetOnboarding() {
    needsOnboarding = true
  }

  /// Called when the user finishes onboarding, so it isn't shown again.
  func markOnboardingComplete() {
    needsOnboarding = false
    persist()
  }

  func resetToDefaults() {
    selectedSeriesIDs = WaxCatalog.defaultSeriesIDs
    hiddenProductIDs = []
    persist()
  }

  private func persist() {
    let value = Persisted(
      selectedSeriesIDs: selectedSeriesIDs,
      hiddenProductIDs: hiddenProductIDs
    )
    if let data = try? JSONEncoder().encode(value) {
      persistenceService.save(data, forKey: AppConstants.PersistenceKeys.waxSelection)
    }
  }
}
