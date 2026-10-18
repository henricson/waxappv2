import SwiftUI

/// A quiet caption showing whether the reading comes from GPS or a manually
/// picked spot. It is information, not a control, so it carries no glass.
struct LocationSourceIndicator: View {
  let isManualOverride: Bool
  let isUsingWeatherData: Bool

  private var icon: String {
    isManualOverride ? "map.fill" : "location.fill"
  }

  var body: some View {
    if isUsingWeatherData {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption2)
        Text(isManualOverride ? "At selected location" : "At your location")
          .font(.caption.weight(.medium))
      }
      .accessibilityIdentifier("locationSourceIndicator")
      .foregroundStyle(.secondary)
      .transition(.blurReplace)
    }
  }
}

#Preview {
  VStack(spacing: 20) {
    LocationSourceIndicator(isManualOverride: false, isUsingWeatherData: true)
    LocationSourceIndicator(isManualOverride: true, isUsingWeatherData: true)
    LocationSourceIndicator(isManualOverride: false, isUsingWeatherData: false)
  }
  .padding()
  .background(.blue.opacity(0.25))
}
