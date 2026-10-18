//
//  TemperatureGauge.swift
//  waxappv2
//

import SwiftUI

/// The fixed centre marker on the Gantt: a glass badge showing the
/// temperature currently under the playhead, with a line dropping through
/// the chart below it.
struct TemperatureGauge: View {
  var temperature: Int

  private var display: TemperatureDisplay { TemperatureDisplay() }

  var body: some View {
    VStack(spacing: 0) {
      Text(display.string(fromCelsius: temperature))
        .font(.system(size: 19, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .contentTransition(.numericText())
        .animation(.smooth(duration: 0.2), value: temperature)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(.accentColor), in: .capsule)

      Rectangle()
        .fill(
          LinearGradient(
            colors: [.accentColor, .accentColor.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 2)
        .frame(maxHeight: .infinity)
    }
    .accessibilityElement()
    .accessibilityLabel("Temperature")
    .accessibilityValue(display.string(fromCelsius: temperature))
  }
}

#Preview {
  TemperatureGauge(temperature: -5)
    .frame(height: 300)
    .background(.blue.opacity(0.2))
}
