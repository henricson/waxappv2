import Foundation

// User-selectable temperature unit for display only.
// The app's internal source of truth remains Celsius.
enum TemperatureUnit: String, CaseIterable, Identifiable {
  case celsius = "C"
  case fahrenheit = "F"

  var id: String { rawValue }

  var symbol: String { self == .celsius ? "°C" : "°F" }

  /// A reasonable major-tick step for axes.
  /// - Celsius: 1° granularity is fine.
  /// - Fahrenheit: 2°F keeps labels readable (1°C ≈ 1.8°F).
  var axisTickStep: Int {
    switch self {
    case .celsius: return 1
    case .fahrenheit: return 2
    }
  }
}

// Centralized helpers for reading/writing the user's temperature unit preference
// and converting values for display.
enum TemperaturePreference {
  static let defaultsKey = "temperatureUnit"

  // Returns the currently selected unit or a sensible default based on device settings.
  static func currentUnit() -> TemperatureUnit {
    if let raw = UserDefaults.standard.string(forKey: defaultsKey),
      let unit = TemperatureUnit(rawValue: raw)
    {
      return unit
    }
    // Default based on device measurement system (metric -> Celsius, otherwise Fahrenheit)
    return Locale.current.usesMetricSystem ? .celsius : .fahrenheit
  }

  static func setUnit(_ unit: TemperatureUnit) {
    UserDefaults.standard.set(unit.rawValue, forKey: defaultsKey)
  }

  // Call once (e.g., at app startup) to ensure a default is persisted.
  static func ensureDefaultInitialized() {
    if UserDefaults.standard.string(forKey: defaultsKey) == nil {
      setUnit(currentUnit())
    }
  }

  @inline(__always)
  static func celsiusToFahrenheit(_ c: Int) -> Int {
    Int((Double(c) * 9.0 / 5.0 + 32.0).rounded())
  }

  @inline(__always)
  static func celsiusToFahrenheit(_ c: Double) -> Double {
    (c * 9.0 / 5.0) + 32.0
  }
}

/// Centralized formatting for temperatures.
/// Keep internal values in Celsius and format at the last moment for UI.
struct TemperatureDisplay {
  let unit: TemperatureUnit

  init(unit: TemperatureUnit = TemperaturePreference.currentUnit()) {
    self.unit = unit
  }

  func value(fromCelsius c: Int) -> Int {
    switch unit {
    case .celsius: return c
    case .fahrenheit: return TemperaturePreference.celsiusToFahrenheit(c)
    }
  }

  func value(fromCelsius c: Double) -> Double {
    switch unit {
    case .celsius: return c
    case .fahrenheit: return TemperaturePreference.celsiusToFahrenheit(c)
    }
  }

  /// String like "-5°C" / "23°F".
  func string(fromCelsius c: Int) -> String {
    "\(value(fromCelsius: c))\(unit.symbol)"
  }

  /// String like "-5°C" / "23°F" with normalized rounding.
  func string(fromCelsius c: Double, rounded: FloatingPointRoundingRule = .toNearestOrAwayFromZero)
    -> String
  {
    let v = value(fromCelsius: c)
    let roundedV = Int(v.rounded(rounded))
    return "\(roundedV)\(unit.symbol)"
  }

  /// Degrees-only label for dense axes: "-5°" / "23°".
  func degreesOnlyString(fromCelsius c: Int) -> String {
    "\(value(fromCelsius: c))°"
  }
}
