import Foundation
import Playgrounds

public struct TempRangeC: Sendable, Equatable {
    public let min: Int  // inclusive, °C
    public let max: Int  // inclusive, °C
    public init(_ min: Int, _ max: Int) { self.min = min; self.max = max }
}

public enum WaxKind: String, Sendable { case hardwax, klister, base }

// A unified snow type enum (converted from individual properties)
// This mirrors Swix’s nine official snow condition categories.
public enum SnowType: CaseIterable, Identifiable, Sendable {
    public var id: Self { self }
    case newFallen                // New fallen snow (dry, sharp crystals)
    case moistNewFallen           // Moist new fallen snow
    case fineGrained              // Fine-grained (dry)
    case moistFineGrained         // Moist fine-grained
    case oldGrained               // Old grained (rounded / partly transformed, generally dry)
    case transformedMoistFine     // Transformed moist fine-grained (near/around 0°C, humid)
    case frozenCorn               // Frozen corn snow / refrozen coarse
    case wetCorn                  // Wet corn snow (free water present)
    case veryWetCorn              // Very wet corn snow (slushy)

    // Norwegian display name for UI
    public var titleNo: String {
        switch self {
        case .newFallen: return "Nysnø"
        case .moistNewFallen: return "Fuktig nysnø"
        case .fineGrained: return "Finkornet"
        case .moistFineGrained: return "Fuktig finkornet"
        case .oldGrained: return "Gammel snø"
        case .transformedMoistFine: return "Omvandlet fuktig finkornet"
        case .frozenCorn: return "Skare/is"
        case .wetCorn: return "Våt grovkornet"
        case .veryWetCorn: return "Svært våt grovkornet"
        }
    }

    // Optional: brief Norwegian description for tooltips/details
    public var descriptionNo: String {
        switch self {
        case .newFallen:
            return "Nylig falt, tørre krystaller (skarpe); krever relativt hard voks."
        case .moistNewFallen:
            return "Nysnø med fuktighet rundt/over 0 °C; fare for ising."
        case .fineGrained:
            return "Tørr finkornet snø; mellomstadiet i transformasjonen."
        case .moistFineGrained:
            return "Finkornet snø med fuktighet; nær 0 °C."
        case .oldGrained:
            return "Gammel/avrundet og bundet snø; siste stadiet i transformasjonen."
        case .transformedMoistFine:
            return "Omvandlet, fuktig finkornet snø rundt 0 °C; ofte blanke spor."
        case .frozenCorn:
            return "Refrosset skare/is; grovkornet og hardt."
        case .wetCorn:
            return "Våt grovkornet snø med fri vann; mykere forhold."
        case .veryWetCorn:
            return "Svært våt/slush; høy vanninnhold."
        }
    }
}

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
        notes: "Changeable, damp–wet transformed; above/below freezing"
    ),

    .init(
        code: "K22", name: "Universal VM Klister", series: "K", kind: .klister,
        ranges: [
            .frozenCorn: [TempRangeC(-3, 10)],
            .wetCorn: [TempRangeC(-3, 10)]
        ],
        notes: "Coarse/old snow from ice/crust to wet"
    ),

    .init(
        code: "KX20", name: "Green Base Klister", series: "KX", kind: .base,
        ranges: [:],
        notes: "Base/binder klister (iron in) for durability on ice & aggressive tracks"
    ),

    .init(
        code: "KX30", name: "Blue Ice Klister", series: "KX", kind: .klister,
        ranges: [
            .frozenCorn: [TempRangeC(-12, 0)]
        ],
        notes: "Icy/frozen coarse tracks; also as underlayer"
    ),

    .init(
        code: "KX35N", name: "Blue Extra Klister", series: "KX", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-8, 0)]
        ],
        notes: "Fine/coarse old snow near and below 0°C"
    ),

    .init(
        code: "KX40S", name: "Silver Klister", series: "KX", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-4, 2)],
            .wetCorn: [TempRangeC(-4, 2)]
        ],
        notes: "Transformed & fine-grained; slightly wet above 0°C"
    ),

    .init(
        code: "KX45N", name: "Violet Special Klister", series: "KX", kind: .klister,
        ranges: [
            .frozenCorn: [TempRangeC(-2, 4)],
            .wetCorn: [TempRangeC(-2, 4)]
        ],
        notes: "All-around for wet/coarse & frozen corn"
    ),

    .init(
        code: "KX55", name: "Violet Extra Klister", series: "KX", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-6, 4)],
            .wetCorn: [TempRangeC(-6, 4)]
        ],
        notes: "Moist transformed to wet/coarse"
    ),

    .init(
        code: "KX65", name: "Red Klister", series: "KX", kind: .klister,
        ranges: [
            .wetCorn: [TempRangeC(1, 5)]
        ],
        notes: "Damp → wet, granular/coarse warm snow"
    ),

    .init(
        code: "KX75", name: "Red Extra Wet Klister", series: "KX", kind: .klister,
        ranges: [
            .veryWetCorn: [TempRangeC(2, 15)]
        ],
        notes: "Very wet/slushy; highest water content"
    ),

    .init(
        code: "KN33", name: "Nero Klister", series: "KN", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-7, 1)],
            .wetCorn: [TempRangeC(-7, 1)]
        ],
        notes: "Racing klister w/ anti-icing; variable conditions"
    ),

    .init(
        code: "KN44", name: "Nero Klister", series: "KN", kind: .klister,
        ranges: [
            .transformedMoistFine: [TempRangeC(-3, 5)],
            .wetCorn: [TempRangeC(-3, 5)]
        ],
        notes: "Warmer Nero; humid transformed/wet"
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
