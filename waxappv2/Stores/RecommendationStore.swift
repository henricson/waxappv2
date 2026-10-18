import Foundation
import Observation

/// Store that computes and manages wax recommendations.
///
/// `effectiveTemperature` and `effectiveSnowType` are synced from
/// `WeatherStore` after each fetch. The user can change them manually
/// (e.g. by scrolling the Gantt chart or picking a snow type).
@MainActor
@Observable
final class RecommendationStore {

  // MARK: - Dependencies

  private let weatherStore: WeatherStore
  private let waxSelectionStore: WaxSelectionStore
  private let defaults: UserDefaults

  // MARK: - State

  /// Temperature used for recommendations. Set by weather fetch or user scroll.
  var effectiveTemperature: Int = -7

  /// Snow type used for recommendations. Set by weather fetch or user picker.
  var effectiveSnowType: SnowType = .fineGrained

  /// Grip or glide — which catalogue the main screen is showing.
  var activeDomain: WaxDomain {
    didSet {
      guard activeDomain != oldValue else { return }
      defaults.set(activeDomain.rawValue, forKey: AppConstants.PersistenceKeys.activeDomain)
    }
  }

  /// When on, the UI explains *why* each recommendation scored as it did.
  var isAdvancedMode: Bool {
    didSet {
      guard isAdvancedMode != oldValue else { return }
      defaults.set(isAdvancedMode, forKey: AppConstants.PersistenceKeys.advancedMode)
    }
  }

  // MARK: - Initialization

  init(
    weatherStore: WeatherStore,
    waxSelectionStore: WaxSelectionStore,
    defaults: UserDefaults = .standard
  ) {
    self.weatherStore = weatherStore
    self.waxSelectionStore = waxSelectionStore
    self.defaults = defaults

    let storedDomain = defaults.string(forKey: AppConstants.PersistenceKeys.activeDomain)
    self.activeDomain = storedDomain.flatMap(WaxDomain.init(rawValue:)) ?? .grip
    self.isAdvancedMode = defaults.bool(forKey: AppConstants.PersistenceKeys.advancedMode)
  }

  // MARK: - Conditions

  /// True when effective values still match the latest weather data.
  var isSameAsWeatherKit: Bool {
    effectiveTemperature == Int(weatherStore.currentTemperature.rounded())
      && effectiveSnowType == weatherStore.currentSnowType
  }

  /// The full condition set handed to the recommender. Weather-derived
  /// signals are kept even when the user overrides temperature or snow type,
  /// since they still describe the snowpack they are standing on.
  var conditions: WaxConditions {
    WaxConditions(
      temperatureC: effectiveTemperature,
      snowType: effectiveSnowType,
      relativeHumidity: weatherStore.currentHumidity,
      recentRainMM: weatherStore.recentRainMM,
      recentSnowMM: weatherStore.recentSnowMM,
      isSnowing: weatherStore.isSnowingNow,
      temperatureTrendC: weatherStore.temperatureTrendC
    )
  }

  // MARK: - Recommendations

  /// Products visible to the user in the active domain.
  var candidates: [WaxProduct] {
    waxSelectionStore.visibleProducts(in: activeDomain)
  }

  /// Snow types worth offering right now: the ones the user's own waxes
  /// actually carry a range for. Derived from the catalogue rather than a
  /// fixed list, so switching domain or turning a series off immediately
  /// stops offering conditions nothing can answer.
  var availableSnowTypes: [SnowType] {
    let products = candidates.filter { !$0.kind.isPreparation }
    guard !products.isEmpty else { return SnowType.allCases }

    let usable = SnowType.allCases.filter { snowType in
      products.contains { !$0.ranges(for: snowType).isEmpty }
    }
    return usable.isEmpty ? SnowType.allCases : usable
  }

  /// Moves the selection onto a snow type that the current library covers.
  /// Called when the domain changes or the library is edited.
  func reconcileSnowType() {
    let available = availableSnowTypes
    guard !available.contains(effectiveSnowType), let fallback = available.first else { return }

    // Prefer the nearest neighbour by raw value so the jump feels small.
    effectiveSnowType =
      available.min {
        abs($0.rawValue - effectiveSnowType.rawValue)
          < abs($1.rawValue - effectiveSnowType.rawValue)
      } ?? fallback
  }

  /// Ranked recommendations for the active domain, best first.
  var recommended: [WaxRecommendation] {
    WaxRecommender.rank(products: candidates, conditions: conditions)
  }

  /// The single best pick, used for the hero display and background tint.
  var topPick: WaxRecommendation? { recommended.first }

  /// Alternatives worth mentioning under the hero: the other waxes whose
  /// published range covers the current temperature.
  ///
  /// This is deliberately the same test the chart draws — a bar under the
  /// temperature line — so "Also works" never names a wax whose bar stops
  /// short of it. Near misses can still score above the cutoff, which used
  /// to make the list and the chart disagree.
  var alternatives: [WaxRecommendation] {
    let topID = topPick?.id
    return Array(
      recommended
        .filter { $0.id != topID && coversCurrentTemperature($0.product) }
        .prefix(3))
  }

  /// True when the product's bar on the chart sits under the temperature line.
  func coversCurrentTemperature(_ product: WaxProduct) -> Bool {
    product.combinedRange(for: effectiveSnowType)?.contains(effectiveTemperature) ?? false
  }

  /// Binder or base prep to lay down first, when the user has one visible.
  var preparation: WaxRecommendation? {
    WaxRecommender.preparation(from: candidates, for: conditions)
  }

  /// True when the user has turned off every series in the active domain.
  var hasNoVisibleSeries: Bool {
    !waxSelectionStore.hasAnySeries(in: activeDomain)
  }

  // MARK: - Public Methods

  /// Syncs effective values from the latest weather data.
  func syncFromWeather() {
    effectiveTemperature = Int(weatherStore.currentTemperature.rounded())
    effectiveSnowType = weatherStore.currentSnowType
  }

  /// Finds the nearest temperature with a recommendation, for the
  /// "move back into range" button.
  func nearestRecommendedTemperature(from current: Int) -> Int? {
    WaxRecommender.nearestUsefulTemperature(
      from: current,
      products: candidates,
      snowType: effectiveSnowType
    )
  }
}
