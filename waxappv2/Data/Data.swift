import Foundation
import SwiftUI

public enum SnowType: Int, CaseIterable, Identifiable, Sendable, Hashable {
    case newFallen = 0               // New fallen snow (dry, sharp crystals)
    case moistNewFallen           // Moist new fallen snow
    case fineGrained              // Fine-grained (dry)
    case moistFineGrained         // Moist fine-grained
    case oldGrained               // Old grained (rounded / partly transformed, generally dry)
    case transformedMoistFine     // Transformed moist fine-grained (near/around 0°C, humid)
    case frozenCorn               // Frozen corn snow / refrozen coarse
    case wetCorn                  // Wet corn snow (free water present)
    case veryWetCorn              // Very wet corn snow (slushy)

    /// UI‑friendly, localized title
    var title: String {
        switch self {
        case .newFallen:               return NSLocalizedString("NewSnowTitle", comment: "")
        case .moistNewFallen:          return NSLocalizedString("MoistNewSnowTitle", comment: "")
        case .fineGrained:             return NSLocalizedString("FineGrainedTitle", comment: "")
        case .moistFineGrained:        return NSLocalizedString("MoistFineGrainedTitle", comment: "")
        case .oldGrained:              return NSLocalizedString("OldGrainedTitle", comment: "")
        case .transformedMoistFine:    return NSLocalizedString("TransformedMoistFineTitle", comment: "")
        case .frozenCorn:              return NSLocalizedString("FrozenCornTitle", comment: "")
        case .wetCorn:                 return NSLocalizedString("WetCornTitle", comment: "")
        case .veryWetCorn:             return NSLocalizedString("VeryWetCornTitle", comment: "")
        }
    }

    /// Brief description for tooltips / detail views
    var description: String {
        switch self {
        case .newFallen:               return NSLocalizedString("NewSnowDesc", comment: "")
        case .moistNewFallen:          return NSLocalizedString("MoistNewSnowDesc", comment: "")
        case .fineGrained:             return NSLocalizedString("FineGrainedDesc", comment: "")
        case .moistFineGrained:        return NSLocalizedString("MoistFineGrainedDesc", comment: "")
        case .oldGrained:              return NSLocalizedString("OldGrainedDesc", comment: "")
        case .transformedMoistFine:    return NSLocalizedString("TransformedMoistFineDesc", comment: "")
        case .frozenCorn:              return NSLocalizedString("FrozenCornDesc", comment: "")
        case .wetCorn:                 return NSLocalizedString("WetCornDesc", comment: "")
        case .veryWetCorn:             return NSLocalizedString("VeryWetCornDesc", comment: "")
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
    public let name: String
    public let series: String   // V, VP, K, KX, KN, etc.
    public let kind: WaxKind

    // Array(s) of temperature ranges per snow type.
    // Use multiple ranges for complicated recommendations (e.g., different subranges).
    public let ranges: [SnowType: [TempRangeC]]

    public let notes: String?
    public let primaryColor: String
    public let secondaryColor: String?

    public init(
        code: String,
        name: String,
        series: String,
        kind: WaxKind,
        ranges: [SnowType: [TempRangeC]] = [:],
        notes: String? = nil,
        primaryColor: String = "#333",
        secondaryColor: String? = nil
    ) {
        self.code = code
        self.name = name
        self.series = series
        self.kind = kind
        self.ranges = ranges
        self.notes = notes
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
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
        if (series == "VP" || series == "KN"), let secondary = secondaryColor {
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
        code: "V05", name: "Polar", series: "V", kind: .hardwax,
        ranges: [
            .newFallen: [TempRangeC(-25, -12)],
            .fineGrained: [TempRangeC(-25, -15)],
            .oldGrained: [TempRangeC(-30, -15)]
        ],
        notes: "Very cold, dry snow",
        primaryColor: "#FFFFFF", secondaryColor: "#000000"
    ),

    .init(
        code: "V20", name: "Green", series: "V", kind: .hardwax,
        ranges: [
            .newFallen: [TempRangeC(-15, -8)],
            .fineGrained: [TempRangeC(-18, -10)],
            .oldGrained: [TempRangeC(-18, -10)]
        ],
        primaryColor: "#70A14D", secondaryColor: "#BED1B0"
    ),

    .init(
        code: "V30", name: "Blue", series: "V", kind: .hardwax,
        ranges: [
            .newFallen: [TempRangeC(-10, -2)],
            .fineGrained: [TempRangeC(-15, -5)],
            .oldGrained: [TempRangeC(-15, -5)]
        ],
        primaryColor: "#3D78E5", secondaryColor: "#ABD5E1"
    ),

    .init(
        code: "V40", name: "Blue Extra", series: "V", kind: .hardwax,
        ranges: [
            .newFallen: [TempRangeC(-7, -1)],
            .fineGrained: [TempRangeC(-10, -3)],
            .oldGrained: [TempRangeC(-10, -3)]
        ],
        primaryColor: "#3D78E5", secondaryColor: "#964472"
    ),

    .init(
        code: "V45", name: "Violet Special", series: "V", kind: .hardwax,
        ranges: [
            .moistNewFallen: [TempRangeC(-3, 0)],
            .moistFineGrained: [TempRangeC(-6, -2)],
            .oldGrained: [TempRangeC(-6, -2)]
        ],
        primaryColor: "#A9276B", secondaryColor: "#4E7FD0"
    ),

    .init(
        code: "V50", name: "Violet", series: "V", kind: .hardwax,
        ranges: [
            .moistNewFallen: [TempRangeC(0, 0)],
            .fineGrained: [TempRangeC(-3, -1)],
            .moistFineGrained: [TempRangeC(-3, -1)]
        ],
        notes: "Around freezing",
        primaryColor: "#704D7B", secondaryColor: "#B1A2B4"
    ),

    .init(
        code: "V55", name: "Red Special", series: "V", kind: .hardwax,
        ranges: [
            .moistNewFallen: [TempRangeC(0, 1)],
            .moistFineGrained: [TempRangeC(-2, 0)],
            .oldGrained: [TempRangeC(-2, 0)]
        ],
        primaryColor: "#B53149", secondaryColor: "#9F4486"
    ),

    .init(
        code: "V60", name: "Red/Silver", series: "V", kind: .hardwax,
        ranges: [
            .moistNewFallen: [TempRangeC(0, 3)],
            .moistFineGrained: [TempRangeC(-1, 1)],
            .transformedMoistFine: [TempRangeC(-1, 1)]
        ],
        notes: "Wet new snow to mild, shiny tracks",
        primaryColor: "#B5332B", secondaryColor: "#909093"
    ),

    .init(
        code: "VP30", name: "Pro Light Blue", series: "VP", kind: .hardwax,
        ranges: [
            .newFallen: [TempRangeC(-16, -8)],
            .fineGrained: [TempRangeC(-16, -8)],
            .oldGrained: [TempRangeC(-20, -12)]
        ],
        notes: "Dry to extra-cold; old snow range from −12 to −20°C per Swix",
        primaryColor: "#000000", secondaryColor: "#ADD8E6"
    ),

    .init(
        code: "VP40", name: "Pro Blue", series: "VP", kind: .hardwax,
        ranges: [
            .newFallen: [TempRangeC(-10, -4)],
            .fineGrained: [TempRangeC(-10, -4)],
            .oldGrained: [TempRangeC(-14, -5)]
        ],
        primaryColor: "#000000", secondaryColor: "#0000FF"
    ),

    .init(
        code: "VP45", name: "Pro Blue/Violet", series: "VP", kind: .hardwax,
        ranges: [
            .newFallen: [TempRangeC(-5, -1)],
            .fineGrained: [TempRangeC(-5, -1)],
            .oldGrained: [TempRangeC(-8, -3)]
        ],
        primaryColor: "#000000", secondaryColor: "#6A5ACD"
    ),

    .init(
        code: "VP50", name: "Pro Light Violet", series: "VP", kind: .hardwax,
        ranges: [
            .newFallen: [TempRangeC(-3, 0)],
            .fineGrained: [TempRangeC(-3, 0)],
            .oldGrained: [TempRangeC(-6, -1)]
        ],
        primaryColor: "#000000", secondaryColor: "#800080"
    ),

    .init(
        code: "VP55", name: "Pro Violet", series: "VP", kind: .hardwax,
        ranges: [
            .moistNewFallen: [TempRangeC(-2, 1)],
            .moistFineGrained: [TempRangeC(0, 1)],
            .oldGrained: [TempRangeC(-5, 0)]
        ],
        primaryColor: "#000000", secondaryColor: "#4B0082"
    ),

    .init(
        code: "VP60", name: "Pro Violet/Red", series: "VP", kind: .hardwax,
        ranges: [
            .moistNewFallen: [TempRangeC(-1, 2)],
            .moistFineGrained: [TempRangeC(-1, 2)],
            .oldGrained: [TempRangeC(-4, -1)]
        ],
        primaryColor: "#000000", secondaryColor: "#B22222"
    ),

    .init(
        code: "VP65", name: "Pro Black/Red", series: "VP", kind: .hardwax,
        ranges: [
            .moistNewFallen: [TempRangeC(0, 2)],
            .oldGrained: [TempRangeC(-4, 0)],
            .transformedMoistFine: [TempRangeC(0, 0)]
        ],
        notes: "Anti-icing black additive; excellent as cover on klister",
        primaryColor: "#000000", secondaryColor: "#8B0000"
    ),

    .init(
        code: "VP70", name: "Pro Yellow (klister-wax)", series: "VP", kind: .hardwax,
        ranges: [
            .moistNewFallen: [TempRangeC(0, 3)],
            .transformedMoistFine: [TempRangeC(-1, 2)]
        ],
        notes: "If very wet new snow or coarse transformed, switch to klister",
        primaryColor: "#000000", secondaryColor: "#FFFF00"
    ),

    // ===== Klister: Universal K, KX, Nero KN =====
    .init(
        code: "K21S", name: "Universal Silver Klister", series: "K", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-5, 3)],
            .wetCorn: [TempRangeC(-5, 3)]
        ],
        notes: "Changeable, damp–wet transformed; above/below freezing",
        primaryColor: "#BDBDBD", secondaryColor: "#5071B0"
    ),

    .init(
        code: "K22", name: "Universal VM Klister", series: "K", kind: .klister,
        ranges: [
            .frozenCorn: [TempRangeC(-3, 10)],
            .wetCorn: [TempRangeC(-3, 10)]
        ],
        notes: "Coarse/old snow from ice/crust to wet",
        primaryColor: "#CCCECB", secondaryColor: "#C14D40"
    ),

    .init(
        code: "KX20", name: "Green Base Klister", series: "KX", kind: .base,
        ranges: [:],
        notes: "Base/binder klister (iron in) for durability on ice & aggressive tracks",
        primaryColor: "#6AAC45", secondaryColor: "#82B45B"
    ),

    .init(
        code: "KX30", name: "Blue Ice Klister", series: "KX", kind: .klister,
        ranges: [
            .frozenCorn: [TempRangeC(-12, 0)]
        ],
        notes: "Icy/frozen coarse tracks; also as underlayer",
        primaryColor: "#509CD6", secondaryColor: "#59A9DF"
    ),

    .init(
        code: "KX35N", name: "Blue Extra Klister", series: "KX", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-8, 0)]
        ],
        notes: "Fine/coarse old snow near and below 0°C",
        primaryColor: "#2C68BD", secondaryColor: "#614AA7"
    ),

    .init(
        code: "KX40S", name: "Silver Klister", series: "KX", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-4, 2)],
            .wetCorn: [TempRangeC(-4, 2)]
        ],
        notes: "Transformed & fine-grained; slightly wet above 0°C",
        primaryColor: "#95989E", secondaryColor: "#612A6A"
    ),

    .init(
        code: "KX45N", name: "Violet Special Klister", series: "KX", kind: .klister,
        ranges: [
            .frozenCorn: [TempRangeC(-2, 4)],
            .wetCorn: [TempRangeC(-2, 4)]
        ],
        notes: "All-around for wet/coarse & frozen corn",
        primaryColor: "#773C89", secondaryColor: "#4294D2"
    ),

    .init(
        code: "KX55", name: "Violet Extra Klister", series: "KX", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-6, 4)],
            .wetCorn: [TempRangeC(-6, 4)]
        ],
        notes: "Moist transformed to wet/coarse",
        primaryColor: "#C63B66", secondaryColor: "#D79D4B"
    ),

    .init(
        code: "KX65", name: "Red Klister", series: "KX", kind: .klister,
        ranges: [
            .wetCorn: [TempRangeC(1, 5)]
        ],
        notes: "Damp → wet, granular/coarse warm snow",
        primaryColor: "#D23A2B", secondaryColor: "#D66B60"
    ),

    .init(
        code: "KX75", name: "Red Extra Wet Klister", series: "KX", kind: .klister,
        ranges: [
            .veryWetCorn: [TempRangeC(2, 15)]
        ],
        notes: "Very wet/slushy; highest water content",
        primaryColor: "#D5452F", secondaryColor: "#DFB53E"
    ),

    .init(
        code: "KN33", name: "Nero Klister", series: "KN", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-7, 1)],
            .wetCorn: [TempRangeC(-7, 1)]
        ],
        notes: "Racing klister w/ anti-icing; variable conditions",
        primaryColor: "#000000", secondaryColor: "#BD74BF"
    ),

    .init(
        code: "KN44", name: "Nero Klister", series: "KN", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-3, 5)],
            .wetCorn: [TempRangeC(-3, 5)]
        ],
        notes: "Warmer Nero; humid transformed/wet",
        primaryColor: "#000000", secondaryColor: "#972921"
    )
]

extension SwixWax {
    var kindDisplay: String {
        switch kind {
        case .hardwax: return "Hardwax"
        case .klister: return "Klister"
        case .base: return "Base"
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

public extension SwixWax {
    var waxSeries: WaxSeries {
        WaxSeries.from(seriesString: series)
    }
}

public extension Array where Element == SwixWax {
    func groupedBySeries() -> [WaxSeries: [SwixWax]] {
        Dictionary(grouping: self) { $0.waxSeries }
    }
}

