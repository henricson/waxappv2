//
//  WaxModel.swift
//  waxappv2
//
//  Brand-agnostic product model shared by every wax catalogue in the app.
//

import Foundation
import SwiftUI

// MARK: - Temperature range

public nonisolated struct TempRangeC: Sendable, Equatable, Hashable {
  public let min: Int  // inclusive, °C
  public let max: Int  // inclusive, °C

  public init(_ min: Int, _ max: Int) {
    // Tolerate ranges written in either order; several manufacturer charts
    // print the warm end first (e.g. "0°C to -3°C").
    self.min = Swift.min(min, max)
    self.max = Swift.max(min, max)
  }

  /// Width in degrees. A single-point range (e.g. Swix V50, "0 °C only") has width 0.
  public var width: Int { max - min }

  public func contains(_ temperature: Int) -> Bool {
    temperature >= min && temperature <= max
  }

  /// Distance from `temperature` to the nearest point inside the range; 0 when inside.
  public func distance(to temperature: Int) -> Int {
    if temperature < min { return min - temperature }
    if temperature > max { return temperature - max }
    return 0
  }
}

// MARK: - Brand

public nonisolated enum WaxBrand: String, CaseIterable, Identifiable, Sendable, Hashable, Codable {
  case swix
  case rode

  public var id: String { rawValue }

  /// Brand names are proper nouns and deliberately not localized.
  public var displayName: String {
    switch self {
    case .swix: return "Swix"
    case .rode: return "Rode"
    }
  }

  /// Accent used for brand chips and section headers.
  public var tintHex: String {
    switch self {
    case .swix: return "#D6252B"
    case .rode: return "#0B4DA2"
    }
  }
}

// MARK: - Domain

/// The two things you put on a ski: grip (kick) wax under the foot,
/// and glide wax on the tips and tails.
public nonisolated enum WaxDomain: String, CaseIterable, Identifiable, Sendable, Hashable, Codable {
  case grip
  case glide

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .grip: return String(localized: "Domain_Grip")
    case .glide: return String(localized: "Domain_Glide")
    }
  }

  public var subtitle: String {
    switch self {
    case .grip: return String(localized: "Domain_Grip_Subtitle")
    case .glide: return String(localized: "Domain_Glide_Subtitle")
    }
  }
}

// MARK: - Kind

public nonisolated enum WaxKind: String, Sendable, CaseIterable, Hashable {
  // Grip
  case hardwax
  case klister
  case binder

  // Glide
  case glideHot
  case glideLiquid
  case glidePowder
  case glideBase

  public var domain: WaxDomain {
    switch self {
    case .hardwax, .klister, .binder: return .grip
    case .glideHot, .glideLiquid, .glidePowder, .glideBase: return .glide
    }
  }

  /// True for products that are preparation layers rather than a wax of the day.
  /// They are never offered as "the" recommendation, only as an accompanying step.
  public var isPreparation: Bool {
    self == .binder || self == .glideBase
  }

  public var displayName: String {
    switch self {
    case .hardwax: return String(localized: "Hardwax")
    case .klister: return String(localized: "Klister")
    case .binder: return String(localized: "Binder")
    case .glideHot: return String(localized: "Kind_GlideHot")
    case .glideLiquid: return String(localized: "Kind_GlideLiquid")
    case .glidePowder: return String(localized: "Kind_GlidePowder")
    case .glideBase: return String(localized: "Kind_GlideBase")
    }
  }
}

// MARK: - Series

/// A product line within a brand (Swix "V", Swix "TS", Rode "P"…).
/// Series are the unit the user turns on and off in the wax picker.
public nonisolated struct WaxSeries: Identifiable, Hashable, Sendable {
  public let brand: WaxBrand
  public let code: String
  public let domain: WaxDomain
  public let nameKey: String
  public let blurbKey: String

  /// Series the app enables for a brand-new install.
  public let isDefaultOn: Bool

  /// Series aimed at racers / wax-room users rather than everyday skiers.
  public let isAdvanced: Bool

  public var id: String { "\(brand.rawValue).\(code)" }

  public var name: String {
    String(localized: String.LocalizationValue(nameKey))
  }

  public var blurb: String {
    String(localized: String.LocalizationValue(blurbKey))
  }

  public init(
    brand: WaxBrand,
    code: String,
    domain: WaxDomain,
    nameKey: String,
    blurbKey: String,
    isDefaultOn: Bool,
    isAdvanced: Bool
  ) {
    self.brand = brand
    self.code = code
    self.domain = domain
    self.nameKey = nameKey
    self.blurbKey = blurbKey
    self.isDefaultOn = isDefaultOn
    self.isAdvanced = isAdvanced
  }
}

// MARK: - Product

public nonisolated struct WaxProduct: Sendable, Identifiable, Hashable {
  /// Globally unique: brand-qualified so Swix K30 and Rode K30 can coexist.
  public var id: String { "\(brand.rawValue).\(code)" }

  public let brand: WaxBrand
  public let code: String
  public let nameKey: String
  public let seriesCode: String
  public let kind: WaxKind

  /// Temperature ranges per snow type.
  ///
  /// Grip waxes are published this way: a wax has no entry for a snow type
  /// it is not meant for, and may carry several sub-ranges for one type.
  public let ranges: [SnowType: [TempRangeC]]

  /// A single published band that does not vary by snow type.
  ///
  /// Glide wax is sold with one air-temperature range regardless of what the
  /// snow has become, so storing nine identical copies in `ranges` would be
  /// inventing data. Snow type still affects the result — through
  /// `snowAffinity`, which is a real, published distinction between
  /// graphite, hydrocarbon and liquid products.
  public let band: TempRangeC?

  public let notesKey: String?
  public let primaryColor: String
  public let secondaryColor: String?

  /// Per-snow-type preference multiplier applied on top of the temperature match.
  ///
  /// Grip waxes encode snow suitability in `ranges`. Glide waxes are sold with a
  /// single temperature band regardless of snow type, so their snow-type
  /// intelligence lives here instead: graphite-loaded products score higher on
  /// transformed, dirty and abrasive snow. Defaults to 1.0 (neutral).
  public let snowAffinity: [SnowType: Double]

  public init(
    brand: WaxBrand,
    code: String,
    nameKey: String,
    seriesCode: String,
    kind: WaxKind,
    ranges: [SnowType: [TempRangeC]] = [:],
    band: TempRangeC? = nil,
    notesKey: String? = nil,
    primaryColor: String = "#333333",
    secondaryColor: String? = nil,
    snowAffinity: [SnowType: Double] = [:]
  ) {
    self.brand = brand
    self.code = code
    self.nameKey = nameKey
    self.seriesCode = seriesCode
    self.kind = kind
    self.ranges = ranges
    self.band = band
    self.notesKey = notesKey
    self.primaryColor = primaryColor
    self.secondaryColor = secondaryColor
    self.snowAffinity = snowAffinity
  }

  // MARK: Derived

  public var domain: WaxDomain { kind.domain }

  public var seriesID: String { "\(brand.rawValue).\(seriesCode)" }

  public var name: String {
    String(localized: String.LocalizationValue(nameKey))
  }

  public var notes: String? {
    guard let notesKey else { return nil }
    return String(localized: String.LocalizationValue(notesKey))
  }

  /// Colour the UI tints itself with for this product.
  ///
  /// Always the primary: the secondary is a printed band on the container and
  /// is often a deliberately contrasting hue, which makes a terrible wash
  /// behind a whole screen.
  public var backgroundColor: String { primaryColor }

  public func ranges(for snowType: SnowType) -> [TempRangeC] {
    if let specific = ranges[snowType] { return specific }
    if let band { return [band] }
    return []
  }

  /// Affinity multiplier for a snow type, 1.0 when unspecified.
  public func affinity(for snowType: SnowType) -> Double {
    snowAffinity[snowType] ?? 1.0
  }

  /// A single combined range for a snow type, spanning all sub-ranges.
  public func combinedRange(for snowType: SnowType) -> TempRangeC? {
    let rs = ranges(for: snowType)
    guard let first = rs.first else { return nil }
    let lo = rs.reduce(first.min) { Swift.min($0, $1.min) }
    let hi = rs.reduce(first.max) { Swift.max($0, $1.max) }
    return TempRangeC(lo, hi)
  }

  public var minValue: CGFloat {
    let all = ranges.values.flatMap { $0 } + (band.map { [$0] } ?? [])
    return CGFloat(all.map(\.min).min() ?? 0)
  }

  public var maxValue: CGFloat {
    let all = ranges.values.flatMap { $0 } + (band.map { [$0] } ?? [])
    return CGFloat(all.map(\.max).max() ?? 0)
  }

  public func minValue(for snowType: SnowType) -> CGFloat {
    CGFloat(ranges(for: snowType).map(\.min).min() ?? 0)
  }

  public func maxValue(for snowType: SnowType) -> CGFloat {
    CGFloat(ranges(for: snowType).map(\.max).max() ?? 0)
  }

  public var kindDisplay: String { kind.displayName }
}

// MARK: - Catalogue

public nonisolated enum WaxCatalog {
  /// Every product the app knows about, across all brands and domains.
  public static let all: [WaxProduct] =
    swixGripWaxes + swixGlideWaxes + rodeGripWaxes

  public static let series: [WaxSeries] =
    swixSeries + rodeSeries

  public static func series(withID id: String) -> WaxSeries? {
    series.first { $0.id == id }
  }

  public static func product(withID id: String) -> WaxProduct? {
    all.first { $0.id == id }
  }

  public static func products(inSeries seriesID: String) -> [WaxProduct] {
    all.filter { $0.seriesID == seriesID }
  }

  public static func series(for brand: WaxBrand, domain: WaxDomain) -> [WaxSeries] {
    series.filter { $0.brand == brand && $0.domain == domain }
  }

  /// Series enabled on a fresh install.
  /// Series enabled on a fresh install: a kit chosen for the user's region.
  public static var defaultSeriesIDs: Set<String> {
    RegionalWaxKit.currentSeriesIDs.intersection(series.map(\.id))
  }

  /// Products belonging to the default series.
  public static var defaultProductIDs: Set<String> {
    let ids = defaultSeriesIDs
    return Set(all.filter { ids.contains($0.seriesID) }.map(\.id))
  }
}

extension Array where Element == WaxProduct {
  public func groupedBySeries() -> [String: [WaxProduct]] {
    Dictionary(grouping: self, by: \.seriesID)
  }
}
