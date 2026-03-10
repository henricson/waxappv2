import Foundation

// MARK: - SnowType Extensions

extension SnowType {
  /// Maps to Swix 5-group classification
  public var swixGroup: Int {
    switch self {
    case .newFallen, .moistNewFallen: return 1
    case .fineGrained, .moistFineGrained: return 2
    case .oldGrained: return 3
    case .wetCorn, .veryWetCorn, .transformedMoistFine: return 4
    case .frozenCorn: return 5
    }
  }

  /// Whether klister is typically required
  public var requiresKlister: Bool {
    switch self {
    case .newFallen, .moistNewFallen, .fineGrained, .moistFineGrained, .oldGrained:
      return false  // Hard wax
    case .transformedMoistFine:
      return false  // Soft hard wax or universal klister
    case .wetCorn, .veryWetCorn, .frozenCorn:
      return true  // Klister
    }
  }

  /// Localized wax guidance
  public var waxGuidance: String {
    switch self {
    case .newFallen: return String(localized: "WaxGuidance_NewFallen")
    case .moistNewFallen: return String(localized: "WaxGuidance_MoistNewFallen")
    case .fineGrained: return String(localized: "WaxGuidance_FineGrained")
    case .moistFineGrained: return String(localized: "WaxGuidance_MoistFineGrained")
    case .oldGrained: return String(localized: "WaxGuidance_OldGrained")
    case .transformedMoistFine: return String(localized: "WaxGuidance_TransformedMoistFine")
    case .wetCorn: return String(localized: "WaxGuidance_WetCorn")
    case .veryWetCorn: return String(localized: "WaxGuidance_VeryWetCorn")
    case .frozenCorn: return String(localized: "WaxGuidance_FrozenCorn")
    }
  }
}
