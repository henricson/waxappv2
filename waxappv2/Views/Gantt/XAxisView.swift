//
//  XAxisView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 03/12/2025.
//
import SwiftUI

struct XAxisView: View {
    let minValue: Int
    let maxValue: Int
    let scaleFactor: Int

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        GeometryReader { geo in
            let h = max(geo.size.height, 1)
            let s = CGFloat(scaleFactor)

            // Pixel-aligned thickness for crisp lines on any scale
            let onePixel = max(1.0 / displayScale, 0.5)

            // Responsive metrics derived from height
            let axisLineHeight = onePixel
            let majorTickHeight = clamp(h * 0.45, min: 8, max: h * 0.75)
            let minorTickHeight = clamp(h * 0.25, min: 4, max: majorTickHeight * 0.8)
            let tickWidth = onePixel
            let labelFontSize = clamp(h * 0.28, min: 8, max: h * 0.6)
            let labelSpacing = clamp(h * 0.06, min: 2, max: h * 0.2)

            ZStack(alignment: .topLeading) {
                // Axis baseline (top)
                Rectangle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(height: axisLineHeight)

                // Minor/major ticks at exact multiples of scaleFactor from minValue
                ForEach(minValue..<maxValue, id: \.self) { value in
                    let x = CGFloat(value - minValue) * s
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: tickWidth, height: (value % 5 == 0) ? majorTickHeight : minorTickHeight)
                        // Position so the tick starts at the baseline and is centered on x
                        .position(x: x, y: ((value % 5 == 0) ? majorTickHeight : minorTickHeight) / 2)
                }

                // Labels every 5°C at exact multiples of scaleFactor
                ForEach(Array(stride(from: minValue, to: maxValue, by: 5)), id: \.self) { value in
                    let x = CGFloat(value - minValue) * s
                    Text("\(value)°")
                        .font(.system(size: labelFontSize))
                        .foregroundColor(.secondary)
                        .position(x: x, y: majorTickHeight + labelSpacing + labelFontSize / 2)
                }
            }
        }
    }

    private func clamp(_ v: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(v, max))
    }
}

#Preview {
    VStack(spacing: 16) {
        XAxisView(minValue: -35, maxValue: 35, scaleFactor: 20)
            .frame(height: 24)
            .background(.ultraThinMaterial)
        XAxisView(minValue: -35, maxValue: 35, scaleFactor: 20)
            .frame(height: 48)
            .background(.ultraThinMaterial)
        XAxisView(minValue: -35, maxValue: 35, scaleFactor: 20)
            .frame(height: 96)
            .background(.ultraThinMaterial)
    }
    .padding()
}
