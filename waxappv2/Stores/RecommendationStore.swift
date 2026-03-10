import Foundation
import Observation

/// Represents a wax recommendation with match scoring
struct WaxRecommendation {
  let wax: SwixWax
  let reason: String
  let percentageMatch: Double
}

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

  // MARK: - State

  /// Temperature used for recommendations. Set by weather fetch or user scroll.
  var effectiveTemperature: Int = -7

  /// Snow type used for recommendations. Set by weather fetch or user picker.
  var effectiveSnowType: SnowType = .fineGrained

  /// True when effective values match the latest WeatherKit data.
  var isSameAsWeatherKit: Bool {
    effectiveTemperature == Int(weatherStore.currentTemperature)
      && effectiveSnowType == weatherStore.currentSnowType
  }

  /// Computed recommendations based on current temperature, snow type, and selected waxes
  var recommended: [WaxRecommendation] {
    let currentTemp = effectiveTemperature
    let currentSnowType = effectiveSnowType
    let selectedIDs = waxSelectionStore.selectedWaxIDs

    let eligibleWaxes = swixWaxes.filter { selectedIDs.contains($0.id) }

    var recommendations: [WaxRecommendation] = []

    for wax in eligibleWaxes {
      guard let range = wax.ranges[currentSnowType]?.first else { continue }
      guard range.min <= currentTemp && currentTemp <= range.max else { continue }

      let matchScore = calculateMatchScore(
        temperature: Double(currentTemp),
        range: range
      )

      recommendations.append(
        WaxRecommendation(
          wax: wax,
          reason: "",
          percentageMatch: matchScore
        ))
    }

    return sortRecommendations(recommendations, snowType: currentSnowType)
  }

  // MARK: - Initialization

  init(weatherStore: WeatherStore, waxSelectionStore: WaxSelectionStore) {
    self.weatherStore = weatherStore
    self.waxSelectionStore = waxSelectionStore
  }

  // MARK: - Public Methods

  /// Syncs effective values from the latest WeatherKit data.
  func syncFromWeather() {
    effectiveTemperature = Int(weatherStore.currentTemperature)
    effectiveSnowType = weatherStore.currentSnowType
  }

  /// Finds the nearest recommended temperature from the current temperature
  func nearestRecommendedTemperature(from current: Int) -> Int? {
    let selectedIDs = waxSelectionStore.selectedWaxIDs
    let eligibleWaxes = swixWaxes.filter { selectedIDs.contains($0.id) }
    let ranges = eligibleWaxes.flatMap { $0.ranges[effectiveSnowType] ?? [] }

    guard !ranges.isEmpty else { return nil }

    var bestTarget = current
    var bestDistance = Int.max

    for range in ranges {
      let clamped = max(range.min, min(current, range.max))
      let distance = abs(clamped - current)

      if distance < bestDistance {
        bestDistance = distance
        bestTarget = clamped
      }
    }

    return bestTarget
  }

  // MARK: - Private Methods

  private func calculateMatchScore(temperature: Double, range: TempRangeC) -> Double {
    let min = Double(range.min)
    let max = Double(range.max)
    let center = (min + max) / 2.0
    let halfWidth = (max - min) / 2.0

    guard halfWidth > 0 else { return 1.0 }

    let distanceToCenter = abs(temperature - center)
    return 1.0 - (distanceToCenter / halfWidth)
  }

  private func sortRecommendations(_ recommendations: [WaxRecommendation], snowType: SnowType)
    -> [WaxRecommendation]
  {
    recommendations.sorted { lhs, rhs in
      if abs(lhs.percentageMatch - rhs.percentageMatch) > 0.01 {
        return lhs.percentageMatch > rhs.percentageMatch
      }

      let widthL = lhs.wax.ranges[snowType]?.first.map { $0.max - $0.min } ?? 0
      let widthR = rhs.wax.ranges[snowType]?.first.map { $0.max - $0.min } ?? 0
      return widthL < widthR
    }
  }
}
