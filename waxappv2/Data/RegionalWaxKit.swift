//
//  RegionalWaxKit.swift
//  waxappv2
//
//  The wax lines a new install starts with, chosen for where the skier is.
//
//  Swix is the market leader in every country the app is localised for, so
//  every kit is built on its everyday lines: V hard wax, the universal and
//  KX klisters, and PS glide. Norway adds Rode's P hard waxes — the Italian
//  brand has a long-standing following among Norwegian classic skiers and is
//  on the shelf next to Swix in most sports shops. Elsewhere Rode is a
//  specialist's brand and is left for the skier to switch on.
//
//  Pro lines (VP, KN, HS, TS…) are never on by default: they are race-day
//  products and would crowd an everyday skier's recommendations.
//

import Foundation

nonisolated enum RegionalWaxKit {
  enum Region: String, Sendable {
    case norway, sweden, finland, iceland, international

    init(regionCode: String?) {
      switch regionCode?.uppercased() {
      case "NO", "SJ": self = .norway
      case "SE": self = .sweden
      case "FI", "AX": self = .finland
      case "IS": self = .iceland
      default: self = .international
      }
    }

    static var current: Region {
      Region(regionCode: Locale.current.region?.identifier)
    }
  }

  private static let swixEveryday: Set<String> = ["swix.V", "swix.K", "swix.KX", "swix.PS"]

  static func seriesIDs(for region: Region) -> Set<String> {
    switch region {
    case .norway:
      return swixEveryday.union(["rode.P"])
    case .sweden, .finland, .iceland:
      return swixEveryday
    case .international:
      // Klister is a niche purchase outside the Nordics; the universal tube
      // covers it without three extra grades.
      return ["swix.V", "swix.K", "swix.PS"]
    }
  }

  static var currentSeriesIDs: Set<String> { seriesIDs(for: .current) }

  /// The country the kit was chosen for, in the user's language, or nil when
  /// the international kit applies.
  static func countryName(for region: Region, locale: Locale = .current) -> String? {
    let code: String
    switch region {
    case .norway: code = "NO"
    case .sweden: code = "SE"
    case .finland: code = "FI"
    case .iceland: code = "IS"
    case .international: return nil
    }
    return locale.localizedString(forRegionCode: code)
  }
}
