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

  static let diameter: CGFloat = 66
  static let magnification: CGFloat = 1.9

  private var display: TemperatureDisplay { TemperatureDisplay() }
  private var labelStep: Int { display.unit.axisTickStep }

  var body: some View {
    let d = Self.diameter
    let nearest = Int(temperature.rounded())

    ZStack {
      ForEach((nearest - 2)...(nearest + 2), id: \.self) { degree in
        mark(for: degree, isCentre: degree == nearest)
          .position(x: xPosition(for: degree), y: d / 2 + 3)
      }
    }
    .frame(width: d, height: d)
    // Edge fade, so numbers slide out under the rim instead of being cut.
    .mask {
      RadialGradient(
        colors: [.black, .black, .black.opacity(0)],
        center: .center, startRadius: 0, endRadius: d / 2)
    }
    .glassEffect(.regular, in: .circle)
    // A small point on the underside, where the scrub line hangs from.
    .overlay(alignment: .bottom) {
      Triangle()
        .fill(.regularMaterial)
        .frame(width: 10, height: 6)
        .offset(y: 5)
    }
    .shadow(color: .black.opacity(0.10), radius: 8, y: 4)
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
        .font(.system(size: 22, weight: isCentre ? .semibold : .regular, design: .rounded))
        .monospacedDigit()
        .foregroundStyle(isCentre ? Color.primary : Color.secondary.opacity(0.7))
        .opacity(isMajor || isCentre ? 1 : 0)
        .fixedSize()
      Capsule()
        .fill(isCentre ? Color.primary.opacity(0.6) : Color.secondary.opacity(isMajor ? 0.45 : 0.25))
        .frame(width: 1.2, height: isCentre ? 12 : 8)
    }
  }

}

private nonisolated struct Triangle: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    path.closeSubpath()
    return path
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
