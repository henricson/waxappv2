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
        /// Key for storing selected wax IDs
        static let selectedWaxIDs = "wax.selection.selectedWaxIDs.v1"
    }
}
