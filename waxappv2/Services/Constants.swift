//
//  Constants.swift
//  waxappv2
//
//  Application-wide constants and configuration values.
//

import Foundation

/// Application constants for configuration and persistence keys.
enum AppConstants {
  /// UserDefaults keys for persistent storage
  enum PersistenceKeys {
    /// Series + per-product overrides (1.1 and later).
    static let waxSelection = "wax.selection.v2"

    /// Pre-1.1 flat set of bare Swix codes. Read once, for migration.
    static let legacySelectedWaxIDs = "wax.selection.selectedWaxIDs.v1"

    /// The active domain (grip / glide) on the main screen.
    static let activeDomain = "app.activeDomain.v1"

    /// Whether the user wants the extra detail in recommendations.
    static let advancedMode = "app.advancedMode.v1"
  }
}
