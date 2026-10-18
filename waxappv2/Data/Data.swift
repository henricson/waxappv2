import Foundation
import SwiftUI

/// The snow classes the app reasons about.
///
/// These map onto the Swix 5-group system (see `SnowType.swixGroup`) but are
/// split finer so that "around zero" conditions, which dominate Nordic
/// waxing decisions, can be distinguished from each other.
public nonisolated enum SnowType: Int, CaseIterable, Identifiable, Sendable, Hashable {
  case newFallen = 0  // New fallen snow (dry, sharp crystals)
  case moistNewFallen  // Moist new fallen snow
  case fineGrained  // Fine-grained (dry)
  case moistFineGrained  // Moist fine-grained
  case oldGrained  // Old grained (rounded / partly transformed, generally dry)
  case transformedMoistFine  // Transformed moist fine-grained (near/around 0°C, humid)
  case frozenCorn  // Frozen corn snow / refrozen coarse
  case wetCorn  // Wet corn snow (free water present)
  case veryWetCorn  // Very wet corn snow (slushy)

  public nonisolated var id: Int { rawValue }

  /// UI-friendly, localized title
  public var title: String {
    switch self {
    case .newFallen: return String(localized: "NewSnowTitle")
    case .moistNewFallen: return String(localized: "MoistNewSnowTitle")
    case .fineGrained: return String(localized: "FineGrainedTitle")
    case .moistFineGrained: return String(localized: "MoistFineGrainedTitle")
    case .oldGrained: return String(localized: "OldGrainedTitle")
    case .transformedMoistFine: return String(localized: "TransformedMoistFineTitle")
    case .frozenCorn: return String(localized: "FrozenCornTitle")
    case .wetCorn: return String(localized: "WetCornTitle")
    case .veryWetCorn: return String(localized: "VeryWetCornTitle")
    }
  }

  /// Two-word label for the horizontal picker, where the full title clips.
  public var shortTitle: String {
    switch self {
    case .newFallen: return String(localized: "NewSnowShort")
    case .moistNewFallen: return String(localized: "MoistNewSnowShort")
    case .fineGrained: return String(localized: "FineGrainedShort")
    case .moistFineGrained: return String(localized: "MoistFineGrainedShort")
    case .oldGrained: return String(localized: "OldGrainedShort")
    case .transformedMoistFine: return String(localized: "TransformedMoistFineShort")
    case .frozenCorn: return String(localized: "FrozenCornShort")
    case .wetCorn: return String(localized: "WetCornShort")
    case .veryWetCorn: return String(localized: "VeryWetCornShort")
    }
  }

  /// Brief description for tooltips / detail views
  public var description: String {
    switch self {
    case .newFallen: return String(localized: "NewSnowDesc")
    case .moistNewFallen: return String(localized: "MoistNewSnowDesc")
    case .fineGrained: return String(localized: "FineGrainedDesc")
    case .moistFineGrained: return String(localized: "MoistFineGrainedDesc")
    case .oldGrained: return String(localized: "OldGrainedDesc")
    case .transformedMoistFine: return String(localized: "TransformedMoistFineDesc")
    case .frozenCorn: return String(localized: "FrozenCornDesc")
    case .wetCorn: return String(localized: "WetCornDesc")
    case .veryWetCorn: return String(localized: "VeryWetCornDesc")
    }
  }

  /// SF Symbol name for this snow type
  public var iconName: String {
    switch self {
    case .newFallen: return "snowflake"
    case .moistNewFallen: return "cloud.snow"
    case .fineGrained: return "hexagon"
    case .moistFineGrained: return "hexagon.lefthalf.filled"
    case .oldGrained: return "circle.grid.2x1"
    case .transformedMoistFine: return "rhombus"
    case .frozenCorn: return "snowflake.circle"
    case .wetCorn: return "drop"
    case .veryWetCorn: return "drop.fill"
    }
  }

  /// True when free water is present in the snowpack.
  public var isWet: Bool {
    switch self {
    case .moistNewFallen, .moistFineGrained, .transformedMoistFine, .wetCorn, .veryWetCorn:
      return true
    case .newFallen, .fineGrained, .oldGrained, .frozenCorn:
      return false
    }
  }

  /// How abrasive the grains are, 0 (soft new crystals) to 1 (coarse refrozen corn).
  /// Drives glide-wax hardness preference.
  public var abrasiveness: Double {
    switch self {
    case .newFallen: return 0.85  // sharp dendrites cut into soft wax
    case .moistNewFallen: return 0.55
    case .fineGrained: return 0.45
    case .moistFineGrained: return 0.35
    case .oldGrained: return 0.40
    case .transformedMoistFine: return 0.50
    case .frozenCorn: return 1.0
    case .wetCorn: return 0.60
    case .veryWetCorn: return 0.45
    }
  }
}

// MARK: - Convenience lookups

/// Products that carry a range for the given snow type.
public func products(for snowType: SnowType, in catalog: [WaxProduct] = WaxCatalog.all)
  -> [WaxProduct]
{
  catalog.filter { !$0.ranges(for: snowType).isEmpty }
}

// MARK: - Glide snow

/// The snow distinctions that actually change a glide wax: clean new snow,
/// fine-grained, coarse or abrasive, and wet. Grip wax needs all nine types;
/// glide wax is ranked by temperature and by which of these it is, so the
/// glide screen offers these four instead.
public nonisolated enum GlideSnow: String, CaseIterable, Identifiable, Sendable {
  case new
  case fine
  case coarse
  case wet

  public var id: String { rawValue }

  /// The snow type a tap on this choice selects.
  public var representative: SnowType {
    switch self {
    case .new: return .newFallen
    case .fine: return .fineGrained
    case .coarse: return .frozenCorn
    case .wet: return .wetCorn
    }
  }

  public init(_ snowType: SnowType) {
    switch snowType {
    case .newFallen, .moistNewFallen: self = .new
    case .fineGrained, .moistFineGrained: self = .fine
    case .oldGrained, .transformedMoistFine, .frozenCorn: self = .coarse
    case .wetCorn, .veryWetCorn: self = .wet
    }
  }

  public var title: String {
    switch self {
    case .new: return String(localized: "GlideSnow_New")
    case .fine: return String(localized: "GlideSnow_Fine")
    case .coarse: return String(localized: "GlideSnow_Coarse")
    case .wet: return String(localized: "GlideSnow_Wet")
    }
  }

  public var detail: String {
    switch self {
    case .new: return String(localized: "GlideSnow_New_Detail")
    case .fine: return String(localized: "GlideSnow_Fine_Detail")
    case .coarse: return String(localized: "GlideSnow_Coarse_Detail")
    case .wet: return String(localized: "GlideSnow_Wet_Detail")
    }
  }

  public var iconName: String {
    switch self {
    case .new: return "snowflake"
    case .fine: return "circle.hexagongrid"
    case .coarse: return "circle.grid.cross"
    case .wet: return "drop"
    }
  }
}
