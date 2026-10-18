//
//  TemperatureLens.swift
//  waxappv2
//
//  A glass loupe resting over the chart's temperature axis, in the spirit
//  of the magnifier in Preview: the scale slides beneath it and the lens
//  shows that same scale enlarged, so the number you are on is read through
//  the glass rather than printed in a fixed badge.
//

import SwiftUI

struct TemperatureLens: View {
  /// The temperature at the centre of the lens; fractional while scrolling.
  var temperature: Double

  static let diameter: CGFloat = 70
  static let magnification: CGFloat = 1.9

  private var display: TemperatureDisplay { TemperatureDisplay() }
  private var labelStep: Int { display.unit.axisTickStep }

  var body: some View {
    let d = Self.diameter
    let nearest = Int(temperature.rounded())

    ZStack {
      ForEach((nearest - 2)...(nearest + 2), id: \.self) { degree in
        mark(for: degree, isCentre: degree == nearest)
          .position(x: xPosition(for: degree), y: d / 2 + 2)
      }
    }
    .frame(width: d, height: d)
    .clipShape(Circle())
    // Clear glass: the page shows through, refracted, under the magnified
    // scale. The axis fades its own labels out beneath the lens so nothing
    // is drawn twice.
    .glassEffect(.clear, in: .circle)
    .overlay { rim }
    .shadow(color: .black.opacity(0.16), radius: 9, y: 5)
    .accessibilityHidden(true)
  }

  private func xPosition(for degree: Int) -> CGFloat {
    let spacing: CGFloat = 48 * Self.magnification
    let offset = CGFloat(Double(degree) - temperature)
    return Self.diameter / 2 + offset * spacing
  }

  private func mark(for degree: Int, isCentre: Bool) -> some View {
    let isMajor = degree % labelStep == 0
    let label = display.degreesOnlyString(fromCelsius: degree)

    return VStack(spacing: 5) {
      Text(label)
        .font(.system(size: 21, weight: isCentre ? .bold : .medium, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(isCentre ? Color.primary : Color.secondary)
        .opacity(isMajor || isCentre ? 1 : 0)
        .fixedSize()
      Capsule()
        .fill(Color.secondary.opacity(isMajor ? 0.7 : 0.35))
        .frame(width: 1.6, height: isMajor ? 14 : 8)
    }
  }

  /// Bright where the light hits the top, darker underneath, so it reads as
  /// a lump of glass rather than a flat disc.
  private var rim: some View {
    Circle()
      .strokeBorder(
        LinearGradient(
          colors: [.white.opacity(0.95), .white.opacity(0.2), .black.opacity(0.15)],
          startPoint: .top, endPoint: .bottom),
        lineWidth: 1.3)
  }
}

#Preview {
  @Previewable @State var t: Double = -6.3
  VStack(spacing: 30) {
    TemperatureLens(temperature: t)
    Slider(value: $t, in: -10...5)
  }
  .padding()
  .background(.blue.opacity(0.15))
}
