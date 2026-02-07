import Foundation
import SwiftUI

private func _waxLocalizationKeys() {
  _ = String(localized: "Wax_V05_Name")
  _ = String(localized: "Wax_V05_Notes")
  _ = String(localized: "Wax_V20_Name")
  _ = String(localized: "Wax_V30_Name")
  _ = String(localized: "Wax_V40_Name")
  _ = String(localized: "Wax_V45_Name")
  _ = String(localized: "Wax_V50_Name")
  _ = String(localized: "Wax_V50_Notes")
  _ = String(localized: "Wax_V55_Name")
  _ = String(localized: "Wax_V60_Name")
  _ = String(localized: "Wax_V60_Notes")
  _ = String(localized: "Wax_VP30_Name")
  _ = String(localized: "Wax_VP30_Notes")
  _ = String(localized: "Wax_VP40_Name")
  _ = String(localized: "Wax_VP45_Name")
  _ = String(localized: "Wax_VP50_Name")
  _ = String(localized: "Wax_VP55_Name")
  _ = String(localized: "Wax_VP60_Name")
  _ = String(localized: "Wax_VP65_Name")
  _ = String(localized: "Wax_VP65_Notes")
  _ = String(localized: "Wax_VP70_Name")
  _ = String(localized: "Wax_VP70_Notes")
  _ = String(localized: "Wax_K21S_Name")
  _ = String(localized: "Wax_K21S_Notes")
  _ = String(localized: "Wax_K22_Name")
  _ = String(localized: "Wax_K22_Notes")
  _ = String(localized: "Wax_KX20_Name")
  _ = String(localized: "Wax_KX20_Notes")
  _ = String(localized: "Wax_KX30_Name")
  _ = String(localized: "Wax_KX30_Notes")
  _ = String(localized: "Wax_KX35N_Name")
  _ = String(localized: "Wax_KX35N_Notes")
  _ = String(localized: "Wax_KX40S_Name")
  _ = String(localized: "Wax_KX40S_Notes")
  _ = String(localized: "Wax_KX45N_Name")
  _ = String(localized: "Wax_KX45N_Notes")
  _ = String(localized: "Wax_KX55_Name")
  _ = String(localized: "Wax_KX55_Notes")
  _ = String(localized: "Wax_KX65_Name")
  _ = String(localized: "Wax_KX65_Notes")
  _ = String(localized: "Wax_KX75_Name")
  _ = String(localized: "Wax_KX75_Notes")
  _ = String(localized: "Wax_KN33_Name")
  _ = String(localized: "Wax_KN33_Notes")
  _ = String(localized: "Wax_KN44_Name")
  _ = String(localized: "Wax_KN44_Notes")
}

public enum SnowType: Int, CaseIterable, Identifiable, Sendable, Hashable, Observable {
  case newFallen = 0  // New fallen snow (dry, sharp crystals)
  case moistNewFallen  // Moist new fallen snow
  case fineGrained  // Fine-grained (dry)
  case moistFineGrained  // Moist fine-grained
  case oldGrained  // Old grained (rounded / partly transformed, generally dry)
  case transformedMoistFine  // Transformed moist fine-grained (near/around 0°C, humid)
  case frozenCorn  // Frozen corn snow / refrozen coarse
  case wetCorn  // Wet corn snow (free water present)
  case veryWetCorn  // Very wet corn snow (slushy)

  /// UI‑friendly, localized title
  var title: String {
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

  /// Brief description for tooltips / detail views
  var description: String {
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
  // SF Symbol name for this snow type
  public var iconName: String {
    switch self {
    case .newFallen: return "snow"
    case .moistNewFallen: return "cloud.snow"
    case .fineGrained: return "hexagon"
    case .moistFineGrained: return "hexagon.lefthalf.filled"
    case .oldGrained: return "circle.grid.2x1"
    case .transformedMoistFine: return "rhombus"
    case .frozenCorn: return "snowflake"
    case .wetCorn: return "drop"
    case .veryWetCorn: return "drop.fill"
    }
  }

  public nonisolated var id: Int { self.rawValue }
}

public struct TempRangeC: Sendable, Equatable {
  public let min: Int  // inclusive, °C
  public let max: Int  // inclusive, °C
  public init(_ min: Int, _ max: Int) {
    self.min = min
    self.max = max
  }
}

public enum WaxKind: String, Sendable { case hardwax, klister, base }

// If this playground block causes build issues in app target, comment it out.
// #Playground {
//     print(SnowType.allCases)
// }

public struct SwixWax: Sendable, Identifiable {
  public var id: String { code }
  public let code: String
  public let nameKey: String  // Localization key for name
  public let series: String  // V, VP, K, KX, KN, etc.
  public let kind: WaxKind

  // Array(s) of temperature ranges per snow type.
  // Use multiple ranges for complicated recommendations (e.g., different subranges).
  public let ranges: [SnowType: [TempRangeC]]

  public let notesKey: String?  // Localization key for notes
  public let primaryColor: String
  public let secondaryColor: String?

  public init(
    code: String,
    nameKey: String,
    series: String,
    kind: WaxKind,
    ranges: [SnowType: [TempRangeC]] = [:],
    notesKey: String? = nil,
    primaryColor: String = "#333",
    secondaryColor: String? = nil
  ) {
    self.code = code
    self.nameKey = nameKey
    self.series = series
    self.kind = kind
    self.ranges = ranges
    self.notesKey = notesKey
    self.primaryColor = primaryColor
    self.secondaryColor = secondaryColor
  }

  // Computed properties for localized strings
  public var name: String {
    Bundle.main.localizedString(forKey: nameKey, value: nil, table: nil)
  }

  public var notes: String? {
    guard let key = notesKey else { return nil }
    return Bundle.main.localizedString(forKey: key, value: nil, table: nil)
  }

  // Convenience accessors to compute min/max across provided ranges
  public var minValue: CGFloat {
    let mins = ranges.values
      .flatMap { $0 }
      .map { CGFloat($0.min) }
    return mins.min() ?? 0.0
  }

  public var maxValue: CGFloat {
    let maxs = ranges.values
      .flatMap { $0 }
      .map { CGFloat($0.max) }
    return maxs.max() ?? 0.0
  }

  public var backgroundColor: String {
    if series == "VP" || series == "KN", let secondary = secondaryColor {
      return secondary
    }
    return primaryColor
  }

  // Helper to get the ranges for a specific snow type
  public func ranges(for snowType: SnowType) -> [TempRangeC] {
    ranges[snowType] ?? []
  }
}

public let swixWaxes: [SwixWax] = [

  // ===== V series (classic hardwaxes; recreational/training) =====
  SwixWax(
    code: "V05", nameKey: "Wax_V05_Name", series: "V", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-25, -12)],
      .fineGrained: [TempRangeC(-25, -15)],
      .oldGrained: [TempRangeC(-30, -15)],
    ],
    notesKey: "Wax_V05_Notes",
    primaryColor: "#FFFFFF", secondaryColor: "#000000"
  ),

  .init(
    code: "V20", nameKey: "Wax_V20_Name", series: "V", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-15, -8)],
      .fineGrained: [TempRangeC(-18, -10)],
      .oldGrained: [TempRangeC(-18, -10)],
    ],
    primaryColor: "#70A14D", secondaryColor: "#BED1B0"
  ),

  .init(
    code: "V30", nameKey: "Wax_V30_Name", series: "V", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-10, -2)],
      .fineGrained: [TempRangeC(-15, -5)],
      .oldGrained: [TempRangeC(-15, -5)],
    ],
    primaryColor: "#3D78E5", secondaryColor: "#ABD5E1"
  ),

  .init(
    code: "V40", nameKey: "Wax_V40_Name", series: "V", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-7, -1)],
      .fineGrained: [TempRangeC(-10, -3)],
      .oldGrained: [TempRangeC(-10, -3)],
    ],
    primaryColor: "#3D78E5", secondaryColor: "#964472"
  ),

  .init(
    code: "V45", nameKey: "Wax_V45_Name", series: "V", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(-3, 0)],
      .moistFineGrained: [TempRangeC(-6, -2)],
      .oldGrained: [TempRangeC(-6, -2)],
    ],
    primaryColor: "#A9276B", secondaryColor: "#4E7FD0"
  ),

  .init(
    code: "V50", nameKey: "Wax_V50_Name", series: "V", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 0)],
      .fineGrained: [TempRangeC(-3, -1)],
      .moistFineGrained: [TempRangeC(-3, -1)],
    ],
    notesKey: "Wax_V50_Notes",
    primaryColor: "#704D7B", secondaryColor: "#B1A2B4"
  ),

  .init(
    code: "V55", nameKey: "Wax_V55_Name", series: "V", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 1)],
      .moistFineGrained: [TempRangeC(-2, 0)],
      .oldGrained: [TempRangeC(-2, 0)],
    ],
    primaryColor: "#B53149", secondaryColor: "#9F4486"
  ),

  .init(
    code: "V60", nameKey: "Wax_V60_Name", series: "V", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 3)],
      .moistFineGrained: [TempRangeC(-1, 1)],
      .transformedMoistFine: [TempRangeC(-1, 1)],
    ],
    notesKey: "Wax_V60_Notes",
    primaryColor: "#B5332B", secondaryColor: "#909093"
  ),

  .init(
    code: "VP30", nameKey: "Wax_VP30_Name", series: "VP", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-16, -8)],
      .fineGrained: [TempRangeC(-16, -8)],
      .oldGrained: [TempRangeC(-20, -12)],
    ],
    notesKey: "Wax_VP30_Notes",
    primaryColor: "#000000", secondaryColor: "#ADD8E6"
  ),

  .init(
    code: "VP40", nameKey: "Wax_VP40_Name", series: "VP", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-10, -4)],
      .fineGrained: [TempRangeC(-10, -4)],
      .oldGrained: [TempRangeC(-14, -5)],
    ],
    primaryColor: "#000000", secondaryColor: "#0000FF"
  ),

  .init(
    code: "VP45", nameKey: "Wax_VP45_Name", series: "VP", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-5, -1)],
      .fineGrained: [TempRangeC(-5, -1)],
      .oldGrained: [TempRangeC(-8, -3)],
    ],
    primaryColor: "#000000", secondaryColor: "#6A5ACD"
  ),

  .init(
    code: "VP50", nameKey: "Wax_VP50_Name", series: "VP", kind: .hardwax,
    ranges: [
      .newFallen: [TempRangeC(-3, 0)],
      .fineGrained: [TempRangeC(-3, 0)],
      .oldGrained: [TempRangeC(-6, -1)],
    ],
    primaryColor: "#000000", secondaryColor: "#800080"
  ),

  .init(
    code: "VP55", nameKey: "Wax_VP55_Name", series: "VP", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(-2, 1)],
      .moistFineGrained: [TempRangeC(0, 1)],
      .oldGrained: [TempRangeC(-5, 0)],
    ],
    primaryColor: "#000000", secondaryColor: "#4B0082"
  ),

  .init(
    code: "VP60", nameKey: "Wax_VP60_Name", series: "VP", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(-1, 2)],
      .moistFineGrained: [TempRangeC(-1, 2)],
      .oldGrained: [TempRangeC(-4, -1)],
    ],
    primaryColor: "#000000", secondaryColor: "#B22222"
  ),

  .init(
    code: "VP65", nameKey: "Wax_VP65_Name", series: "VP", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 2)],
      .oldGrained: [TempRangeC(-4, 0)],
      .transformedMoistFine: [TempRangeC(0, 0)],
    ],
    notesKey: "Wax_VP65_Notes",
    primaryColor: "#000000", secondaryColor: "#8B0000"
  ),

  .init(
    code: "VP70", nameKey: "Wax_VP70_Name", series: "VP", kind: .hardwax,
    ranges: [
      .moistNewFallen: [TempRangeC(0, 3)],
      .transformedMoistFine: [TempRangeC(-1, 2)],
    ],
    notesKey: "Wax_VP70_Notes",
    primaryColor: "#000000", secondaryColor: "#FFFF00"
  ),

  // ===== Klister: Universal K, KX, Nero KN =====
  .init(
    code: "K21S", nameKey: "Wax_K21S_Name", series: "K", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-5, 3)],
      .wetCorn: [TempRangeC(-5, 3)],
    ],
    notesKey: "Wax_K21S_Notes",
    primaryColor: "#BDBDBD", secondaryColor: "#5071B0"
  ),

  .init(
    code: "K22", nameKey: "Wax_K22_Name", series: "K", kind: .klister,
    ranges: [
      .frozenCorn: [TempRangeC(-3, 10)],
      .wetCorn: [TempRangeC(-3, 10)],
    ],
    notesKey: "Wax_K22_Notes",
    primaryColor: "#CCCECB", secondaryColor: "#C14D40"
  ),

  .init(
    code: "KX20", nameKey: "Wax_KX20_Name", series: "KX", kind: .base,
    ranges: [:],
    notesKey: "Wax_KX20_Notes",
    primaryColor: "#6AAC45", secondaryColor: "#82B45B"
  ),

  .init(
    code: "KX30", nameKey: "Wax_KX30_Name", series: "KX", kind: .klister,
    ranges: [
      .frozenCorn: [TempRangeC(-12, 0)]
    ],
    notesKey: "Wax_KX30_Notes",
    primaryColor: "#509CD6", secondaryColor: "#59A9DF"
  ),

  .init(
    code: "KX35N", nameKey: "Wax_KX35N_Name", series: "KX", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-8, 0)]
    ],
    notesKey: "Wax_KX35N_Notes",
    primaryColor: "#2C68BD", secondaryColor: "#614AA7"
  ),

  .init(
    code: "KX40S", nameKey: "Wax_KX40S_Name", series: "KX", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-4, 2)],
      .wetCorn: [TempRangeC(-4, 2)],
    ],
    notesKey: "Wax_KX40S_Notes",
    primaryColor: "#95989E", secondaryColor: "#612A6A"
  ),

  .init(
    code: "KX45N", nameKey: "Wax_KX45N_Name", series: "KX", kind: .klister,
    ranges: [
      .frozenCorn: [TempRangeC(-2, 4)],
      .wetCorn: [TempRangeC(-2, 4)],
    ],
    notesKey: "Wax_KX45N_Notes",
    primaryColor: "#773C89", secondaryColor: "#4294D2"
  ),

  .init(
    code: "KX55", nameKey: "Wax_KX55_Name", series: "KX", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-6, 4)],
      .wetCorn: [TempRangeC(-6, 4)],
    ],
    notesKey: "Wax_KX55_Notes",
    primaryColor: "#C63B66", secondaryColor: "#D79D4B"
  ),

  .init(
    code: "KX65", nameKey: "Wax_KX65_Name", series: "KX", kind: .klister,
    ranges: [
      .wetCorn: [TempRangeC(1, 5)]
    ],
    notesKey: "Wax_KX65_Notes",
    primaryColor: "#D23A2B", secondaryColor: "#D66B60"
  ),

  .init(
    code: "KX75", nameKey: "Wax_KX75_Name", series: "KX", kind: .klister,
    ranges: [
      .veryWetCorn: [TempRangeC(2, 15)]
    ],
    notesKey: "Wax_KX75_Notes",
    primaryColor: "#D5452F", secondaryColor: "#DFB53E"
  ),

  .init(
    code: "KN33", nameKey: "Wax_KN33_Name", series: "KN", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-7, 1)],
      .wetCorn: [TempRangeC(-7, 1)],
    ],
    notesKey: "Wax_KN33_Notes",
    primaryColor: "#000000", secondaryColor: "#BD74BF"
  ),

  .init(
    code: "KN44", nameKey: "Wax_KN44_Name", series: "KN", kind: .klister,
    ranges: [
      .transformedMoistFine: [TempRangeC(-3, 5)],
      .wetCorn: [TempRangeC(-3, 5)],
    ],
    notesKey: "Wax_KN44_Notes",
    primaryColor: "#000000", secondaryColor: "#972921"
  ),
]

extension SwixWax {
  var kindDisplay: String {
    switch kind {
    case .hardwax: return String(localized: "Hardwax")
    case .klister: return String(localized: "Klister")
    case .base: return String(localized: "Base")
    }
  }
}

extension SwixWax {
  // Minimum temperature for a specific snow type across all ranges in that type
  public func minValue(for snowType: SnowType) -> CGFloat {
    let mins = ranges[snowType]?.map { CGFloat($0.min) } ?? []
    return mins.min() ?? 0.0
  }

  // Maximum temperature for a specific snow type across all ranges in that type
  public func maxValue(for snowType: SnowType) -> CGFloat {
    let maxs = ranges[snowType]?.map { CGFloat($0.max) } ?? []
    return maxs.max() ?? 0.0
  }
}

// Returns a array of waxes with this snowType and add minValue and maxValue properties for that snow types temperature range
func returnWaxesForSnowType(snowType: SnowType) -> [SwixWax] {
  return swixWaxes.filter { wax in
    guard let rangesForType = wax.ranges[snowType] else { return false }
    return !rangesForType.isEmpty
  }
}

public enum WaxSeries: String, CaseIterable, Identifiable, Sendable {
  public var id: Self { self }

  case V
  case VP
  case K
  case KX
  case KN

  case other

  public var title: String {
    switch self {
    case .V: return "V"
    case .VP: return "VP"
    case .K: return "K"
    case .KX: return "KX"
    case .KN: return "KN"
    case .other: return "Other"
    }
  }

  public static func from(seriesString: String) -> WaxSeries {
    WaxSeries(rawValue: seriesString.uppercased()) ?? .other
  }
}

extension SwixWax {
  public var waxSeries: WaxSeries {
    WaxSeries.from(seriesString: series)
  }
}

extension Array where Element == SwixWax {
  public func groupedBySeries() -> [WaxSeries: [SwixWax]] {
    Dictionary(grouping: self) { $0.waxSeries }
  }
}
