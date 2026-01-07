//
//  SeriesSelectionState.swift
//  waxappv2
//
//  Enum representing the selection state of wax series.
//

import Foundation

/// Represents the selection state for a wax series.
/// Indicates whether none, some, or all waxes in a series are selected.
enum SeriesSelectionState {
    /// No waxes in the series are selected
    case none
    /// Some (but not all) waxes in the series are selected
    case some
    /// All waxes in the series are selected
    case all
}
