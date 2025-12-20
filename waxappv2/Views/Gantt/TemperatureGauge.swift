

import SwiftUI

struct TemperatureGauge: View {
    var temperature: Int
    
    var body: some View {
        GeometryReader { geometry in
            Text("\(temperature)°")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    GaugeBackgroundShape(
                        totalHeight: geometry.size.height,
                        stemWidth: 4,
                        cornerRadius: 20
                    )
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                )
                .overlay(
                    GaugeBackgroundShape(
                        totalHeight: geometry.size.height,
                        stemWidth: 4,
                        cornerRadius: 20
                    )
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

struct GaugeBackgroundShape: Shape {
    var totalHeight: CGFloat
    var stemWidth: CGFloat = 4
    var cornerRadius: CGFloat = 8
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect
        let stemRightX = r.midX + stemWidth / 2
        let stemLeftX = r.midX - stemWidth / 2
        
        // Start at Top-Left (after corner)
        path.move(to: CGPoint(x: r.minX + cornerRadius, y: r.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: r.maxX - cornerRadius, y: r.minY))
        
        // Top-Right corner
        path.addArc(center: CGPoint(x: r.maxX - cornerRadius, y: r.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(270),
                    endAngle: .degrees(0),
                    clockwise: false)
        
        // Right edge
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - cornerRadius))
        
        // Bottom-Right corner
        path.addArc(center: CGPoint(x: r.maxX - cornerRadius, y: r.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false)
        
        // Bottom edge to stem
        path.addLine(to: CGPoint(x: stemRightX, y: r.maxY))
        
        // Stem down
        path.addLine(to: CGPoint(x: stemRightX, y: totalHeight))
        
        // Stem bottom
        path.addLine(to: CGPoint(x: stemLeftX, y: totalHeight))
        
        // Stem up
        path.addLine(to: CGPoint(x: stemLeftX, y: r.maxY))
        
        // Bottom edge from stem
        path.addLine(to: CGPoint(x: r.minX + cornerRadius, y: r.maxY))
        
        // Bottom-Left corner
        path.addArc(center: CGPoint(x: r.minX + cornerRadius, y: r.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false)
        
        // Left edge
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + cornerRadius))
        
        // Top-Left corner
        path.addArc(center: CGPoint(x: r.minX + cornerRadius, y: r.minY + cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false)
        
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    TemperatureGauge(temperature: -5)
}
