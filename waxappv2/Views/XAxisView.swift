//
//  XAxisView.swift
//  waxappv2
//

import SwiftUI

struct XAxisView: View {
  var minTemp: Double
  var maxTemp: Double
  var pxPerDegree: Double
  var tickXOffset: Double
  var tickLineWidth: Double
  var axisHeight: Double
  var centerX: CGFloat

  private var display: TemperatureDisplay { TemperatureDisplay() }

  /// Label every degree in Celsius, every other one in Fahrenheit — 1 °C is
  /// 1.8 °F, so labelling them all would collide.
  private var labelStep: Int { display.unit.axisTickStep }

  var body: some View {
    GeometryReader { geometry in
      ForEach(Int(minTemp)...Int(maxTemp), id: \.self) { degree in
        let x = (Double(degree) - minTemp) * pxPerDegree + tickXOffset
        let isMajor = degree % labelStep == 0

        VStack(spacing: 2) {
          if isMajor {
            Text(display.degreesOnlyString(fromCelsius: degree))
              .font(.caption2)
              .monospacedDigit()
              .foregroundStyle(degree == 0 ? .primary : .secondary)
          }

          Rectangle()
            .fill(.secondary.opacity(isMajor ? 0.65 : 0.3))
            .frame(width: tickLineWidth, height: isMajor ? 8 : 4)
        }
        .position(x: x, y: geometry.size.height - 15)
      }
    }
    .accessibilityHidden(true)
  }
}

#Preview {
  ScrollView(.horizontal) {
    XAxisView(
      minTemp: -30, maxTemp: 30, pxPerDegree: 50, tickXOffset: 25, tickLineWidth: 1,
      axisHeight: 50, centerX: 3050 / 2
    )
    .frame(width: 3050, height: 60)
  }
}
