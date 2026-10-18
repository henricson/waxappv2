//
//  WaxRecommender.swift
//  waxappv2
//
//  Pure scoring engine for grip and glide recommendations.
//
//  Kept free of SwiftUI and of any store so it can be unit-tested directly.
//

import Foundation

// MARK: - Conditions

/// Everything the recommender is allowed to reason about.
public nonisolated struct WaxConditions: Sendable, Equatable {
  public var temperatureC: Int
  public var snowType: SnowType

  /// Relative humidity, 0…1. `nil` when unknown.
  public var relativeHumidity: Double?

  /// Liquid precipitation in the last 24 h, mm.
  public var recentRainMM: Double

  /// Snowfall in the last 24 h, mm.
  public var recentSnowMM: Double

  /// True when precipitation is falling as snow right now.
  public var isSnowing: Bool

  /// Change in air temperature over the last 6 h, °C. `nil` when unknown.
  public var temperatureTrendC: Double?

  public init(
    temperatureC: Int,
    snowType: SnowType,
    relativeHumidity: Double? = nil,
    recentRainMM: Double = 0,
    recentSnowMM: Double = 0,
    isSnowing: Bool = false,
    temperatureTrendC: Double? = nil
  ) {
    self.temperatureC = temperatureC
    self.snowType = snowType
    self.relativeHumidity = relativeHumidity
    self.recentRainMM = recentRainMM
    self.recentSnowMM = recentSnowMM
    self.isSnowing = isSnowing
    self.temperatureTrendC = temperatureTrendC
  }
}

// MARK: - Result

/// One factor that moved a product's score, surfaced in advanced mode.
public nonisolated struct RecommendationFactor: Sendable, Equatable, Identifiable {
  public enum Kind: String, Sendable, Equatable {
    case temperature
    case snowType
    case specificity
    case humidity
    case rain
    case freshSnow
    case abrasion
    case warming
  }

  public let kind: Kind
  public let detail: String
  /// Multiplier this factor contributed. 1.0 is neutral.
  public let impact: Double

  public var id: String { kind.rawValue }

  /// True when the factor helped, for colouring the chip.
  public var isPositive: Bool { impact >= 1.0 }
}

public nonisolated struct WaxRecommendation: Sendable, Equatable, Identifiable {
  public let product: WaxProduct
  /// 0…1. Above `WaxRecommender.confidentThreshold` is a solid match.
  public let score: Double
  public let matchedRange: TempRangeC
  public let factors: [RecommendationFactor]

  public var id: String { product.id }

  /// Percentage for display.
  public var percentageMatch: Double { score }
}

// MARK: - Recommender

public nonisolated enum WaxRecommender {

  /// Scores at or above this are presented without a caveat.
  public static let confidentThreshold: Double = 0.55

  /// Products whose score falls below this are not shown at all.
  public static let cutoff: Double = 0.08

  // MARK: Public API

  /// Ranks `products` for the given conditions, best first.
  /// Preparation layers (binders, base prep) are excluded — use
  /// `preparation(from:for:)` for those.
  public static func rank(
    products: [WaxProduct],
    conditions: WaxConditions
  ) -> [WaxRecommendation] {
    products
      .filter { !$0.kind.isPreparation }
      .compactMap { score($0, conditions: conditions) }
      .filter { $0.score >= cutoff }
      .sorted(by: isBetter)
  }

  /// The preparation layer (binder / base prep) that fits these conditions,
  /// if the user has one visible. Shown as an accompanying step, never as
  /// the recommendation itself.
  public static func preparation(
    from products: [WaxProduct],
    for conditions: WaxConditions
  ) -> WaxRecommendation? {
    products
      .filter { $0.kind.isPreparation }
      .compactMap { score($0, conditions: conditions) }
      .filter { $0.score >= cutoff }
      .sorted(by: isBetter)
      .first
  }

  /// Nearest temperature at which any of `products` has something to say.
  /// Used by the "move back into range" affordance.
  public static func nearestUsefulTemperature(
    from current: Int,
    products: [WaxProduct],
    snowType: SnowType
  ) -> Int? {
    let ranges =
      products
      .filter { !$0.kind.isPreparation }
      .flatMap { $0.ranges(for: snowType) }

    guard !ranges.isEmpty else { return nil }

    return
      ranges
      .map { max($0.min, min(current, $0.max)) }
      .min(by: { abs($0 - current) < abs($1 - current) })
  }

  // MARK: Scoring

  static func score(_ product: WaxProduct, conditions: WaxConditions) -> WaxRecommendation? {
    let ranges = product.ranges(for: conditions.snowType)
    guard !ranges.isEmpty else { return nil }

    // A product may list several sub-ranges for one snow type; take its best.
    var best: (range: TempRangeC, value: Double)?
    for range in ranges {
      let value = temperatureScore(for: conditions.temperatureC, in: range)
      if best == nil || value > best!.value {
        best = (range, value)
      }
    }
    guard let best, best.value > 0 else { return nil }

    var factors: [RecommendationFactor] = []
    var total = best.value

    factors.append(
      RecommendationFactor(
        kind: .temperature,
        detail: temperatureDetail(for: conditions.temperatureC, in: best.range),
        impact: best.value
      ))

    // Specificity: narrow advice beats a catch-all, but only mildly.
    let specificity = 1.0 / (1.0 + Double(best.range.width) / 12.0)
    let specificityImpact = 0.85 + 0.15 * specificity
    total *= specificityImpact
    if best.range.width <= 4 || best.range.width >= 14 {
      factors.append(
        RecommendationFactor(
          kind: .specificity,
          detail: best.range.width <= 4
            ? String(localized: "Factor_Narrow_Range")
            : String(localized: "Factor_Wide_Range"),
          impact: specificityImpact
        ))
    }

    // Snow-type affinity — the main lever for glide wax.
    let affinity = product.affinity(for: conditions.snowType)
    if affinity != 1.0 {
      total *= affinity
      factors.append(
        RecommendationFactor(
          kind: .snowType,
          detail: String(
            localized: "Factor_Snow_Affinity \(conditions.snowType.title)"),
          impact: affinity
        ))
    }

    for modifier in modifiers(for: product, conditions: conditions) {
      total *= modifier.impact
      factors.append(modifier)
    }

    return WaxRecommendation(
      product: product,
      score: min(1.0, max(0.0, total)),
      matchedRange: best.range,
      factors: factors
    )
  }

  /// Flat-topped score inside the range, decaying outside it.
  ///
  /// Inside, a wax is good across most of its band — only the very edges
  /// should lose much — so the curve is a quartic that stays at 0.75 at the
  /// range boundary rather than falling to zero.
  static func temperatureScore(for temperature: Int, in range: TempRangeC) -> Double {
    if range.width == 0 {
      // Manufacturer published a single point (e.g. Swix V50, "0 °C").
      let distance = abs(temperature - range.min)
      if distance == 0 { return 1.0 }
      return max(0.0, 0.70 - 0.20 * Double(distance))
    }

    if range.contains(temperature) {
      let center = Double(range.min + range.max) / 2.0
      let halfWidth = Double(range.width) / 2.0
      let t = (Double(temperature) - center) / halfWidth  // -1…1
      return 1.0 - 0.25 * pow(t, 4)
    }

    let distance = Double(range.distance(to: temperature))
    return max(0.0, 0.70 - 0.18 * distance)
  }

  // MARK: Condition modifiers

  private static func modifiers(
    for product: WaxProduct,
    conditions: WaxConditions
  ) -> [RecommendationFactor] {
    var result: [RecommendationFactor] = []

    // --- Rain on snow: the strongest klister signal there is.
    if conditions.recentRainMM >= 1.0 {
      let strength = min(1.0, conditions.recentRainMM / 8.0)
      switch product.kind {
      case .klister:
        result.append(
          RecommendationFactor(
            kind: .rain,
            detail: String(localized: "Factor_Rain_Klister"),
            impact: 1.0 + 0.30 * strength
          ))
      case .hardwax:
        result.append(
          RecommendationFactor(
            kind: .rain,
            detail: String(localized: "Factor_Rain_Hardwax"),
            impact: 1.0 - 0.35 * strength
          ))
      default:
        break
      }
    }

    // --- Falling snow: hard wax holds, klister picks up snow and ices.
    if conditions.isSnowing || conditions.recentSnowMM >= 3.0 {
      let strength = conditions.isSnowing ? 1.0 : min(1.0, conditions.recentSnowMM / 10.0)
      switch product.kind {
      case .hardwax:
        result.append(
          RecommendationFactor(
            kind: .freshSnow,
            detail: String(localized: "Factor_FreshSnow_Hardwax"),
            impact: 1.0 + 0.18 * strength
          ))
      case .klister:
        result.append(
          RecommendationFactor(
            kind: .freshSnow,
            detail: String(localized: "Factor_FreshSnow_Klister"),
            impact: 1.0 - 0.30 * strength
          ))
      default:
        break
      }
    }

    // --- Humidity. Damp air makes grip wax ice up and favours a harder
    //     choice; for glide it pushes toward liquids and transformed-snow
    //     products.
    if let rh = conditions.relativeHumidity, rh >= 0.85, conditions.temperatureC > -8 {
      let strength = min(1.0, (rh - 0.85) / 0.15)
      switch product.kind {
      case .glideLiquid:
        result.append(
          RecommendationFactor(
            kind: .humidity,
            detail: String(localized: "Factor_Humidity_Liquid"),
            impact: 1.0 + 0.12 * strength
          ))
      case .hardwax where conditions.temperatureC >= -3:
        result.append(
          RecommendationFactor(
            kind: .humidity,
            detail: String(localized: "Factor_Humidity_Hardwax"),
            impact: 1.0 - 0.12 * strength
          ))
      default:
        break
      }
    }

    // --- Abrasive snow chews through soft glide wax; graphite helps.
    if product.domain == .glide {
      let abrasion = conditions.snowType.abrasiveness
      if abrasion >= 0.8 {
        let isHard = product.kind == .glideHot || product.kind == .glidePowder
        result.append(
          RecommendationFactor(
            kind: .abrasion,
            detail: String(localized: "Factor_Abrasive_Snow"),
            impact: isHard ? 1.08 : 0.94
          ))
      }
    }

    // --- A rising temperature through the freezing point is the classic
    //     "wax for what it will be, not what it is" case.
    if let trend = conditions.temperatureTrendC, trend >= 1.5,
      conditions.temperatureC >= -3, conditions.temperatureC <= 1
    {
      let warmerEnd = product.ranges(for: conditions.snowType).map(\.max).max() ?? 0
      if warmerEnd > conditions.temperatureC {
        result.append(
          RecommendationFactor(
            kind: .warming,
            detail: String(localized: "Factor_Warming"),
            impact: 1.10
          ))
      }
    }

    return result
  }

  // MARK: Ordering

  private static func isBetter(_ lhs: WaxRecommendation, _ rhs: WaxRecommendation) -> Bool {
    if abs(lhs.score - rhs.score) > 0.005 {
      return lhs.score > rhs.score
    }
    // Equal score: prefer the more specific range, then a stable order by id.
    if lhs.matchedRange.width != rhs.matchedRange.width {
      return lhs.matchedRange.width < rhs.matchedRange.width
    }
    return lhs.product.id < rhs.product.id
  }

  // MARK: Copy

  private static func temperatureDetail(for temperature: Int, in range: TempRangeC) -> String {
    if range.contains(temperature) {
      return String(localized: "Factor_Temp_InRange \(range.min) \(range.max)")
    }
    return String(localized: "Factor_Temp_OutOfRange \(range.min) \(range.max)")
  }
}
