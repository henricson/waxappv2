import SwiftUI

struct KlisterCanView: View {
    // Default colors based on the SVG, but customizable
    var tipColor: Color = .black
    var bodyColor: Color = Color(red: 0.85, green: 0.85, blue: 0.85) // #D8D8D8
    var eraserColor: Color = .black
    var stripeColor: Color = Color(red: 0.11, green: 0.11, blue: 0.11) // #1C1C1C
    var middleSectionGradient: LinearGradient = LinearGradient(
        gradient: Gradient(colors: [Color(red: 0.13, green: 0.13, blue: 0.13), Color(red: 0.05, green: 0.05, blue: 0.05)]),
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            // Scale factors to normalize the 200x321 SVG coordinates to the view size
            let xScale = width / 200
            let yScale = height / 321

            ZStack {
                
                // 1. Pencil Tip (Black top part)
                Path { path in
                    path.move(to: CGPoint(x: 34.84 * xScale, y: 11 * yScale))
                    path.addCurve(to: CGPoint(x: 103.47 * xScale, y: 0 * yScale), control1: CGPoint(x: 46.68 * xScale, y: 3.67 * yScale), control2: CGPoint(x: 69.56 * xScale, y: 0 * yScale))
                    path.addCurve(to: CGPoint(x: 168.42 * xScale, y: 11 * yScale), control1: CGPoint(x: 137.37 * xScale, y: 0 * yScale), control2: CGPoint(x: 159.02 * xScale, y: 3.67 * yScale))
                    path.addLine(to: CGPoint(x: 170.25 * xScale, y: 42.5 * yScale))
                    path.addCurve(to: CGPoint(x: 103.47 * xScale, y: 30.5 * yScale), control1: CGPoint(x: 164.13 * xScale, y: 34.5 * yScale), control2: CGPoint(x: 141.86 * xScale, y: 30.5 * yScale))
                    path.addCurve(to: CGPoint(x: 33 * xScale, y: 43.5 * yScale), control1: CGPoint(x: 65.07 * xScale, y: 30.5 * yScale), control2: CGPoint(x: 41.58 * xScale, y: 34.83 * yScale))
                    path.addLine(to: CGPoint(x: 34.84 * xScale, y: 11 * yScale))
                    path.closeSubpath()
                }
                .fill(tipColor)
                

                // 2. Main Body (Lower Shaft)
                Path { path in
                    path.move(to: CGPoint(x: 21.43 * xScale, y: 100 * yScale))
                    path.addCurve(to: CGPoint(x: 101.43 * xScale, y: 91 * yScale), control1: CGPoint(x: 48.10 * xScale, y: 94 * yScale), control2: CGPoint(x: 74.76 * xScale, y: 91 * yScale))
                    path.addCurve(to: CGPoint(x: 181.43 * xScale, y: 100 * yScale), control1: CGPoint(x: 128.10 * xScale, y: 91 * yScale), control2: CGPoint(x: 154.76 * xScale, y: 94 * yScale))
                    path.addLine(to: CGPoint(x: 201.43 * xScale, y: 320.60 * yScale))
                    path.addLine(to: CGPoint(x: 1.43 * xScale, y: 320.60 * yScale))
                    path.addLine(to: CGPoint(x: 21.43 * xScale, y: 100 * yScale))
                    path.closeSubpath()
                }
                .fill(bodyColor)
                
                
                // 3. Upper Body Connection
                Path { path in
                    path.move(to: CGPoint(x: 21.43 * xScale, y: 100 * yScale))
                    path.addCurve(to: CGPoint(x: 101.43 * xScale, y: 74 * yScale), control1: CGPoint(x: 46.60 * xScale, y: 82.67 * yScale), control2: CGPoint(x: 73.27 * xScale, y: 74 * yScale))
                    path.addCurve(to: CGPoint(x: 181.43 * xScale, y: 100 * yScale), control1: CGPoint(x: 129.59 * xScale, y: 74 * yScale), control2: CGPoint(x: 156.26 * xScale, y: 82.67 * yScale))
                    path.addCurve(to: CGPoint(x: 101.43 * xScale, y: 91 * yScale), control1: CGPoint(x: 154.76 * xScale, y: 94 * yScale), control2: CGPoint(x: 128.10 * xScale, y: 91 * yScale))
                    path.addCurve(to: CGPoint(x: 21.43 * xScale, y: 100 * yScale), control1: CGPoint(x: 74.76 * xScale, y: 91 * yScale), control2: CGPoint(x: 48.10 * xScale, y: 94 * yScale))
                    path.closeSubpath()
                }
                .fill(Color(hex: "#D8D8D8")!)

               
                
                // 5. Stripes (The texture on top of the tip)
                // Note: I have simplified the repeated lines into a loop for efficiency
                // The original SVG used a mask, here we just overlay them clipped to the tip shape
                PencilStripesShape()
                    .stroke(stripeColor, lineWidth: 1 * xScale) // Scale line width
                    .mask(
                        Path { path in
                             // Reusing the tip path for masking
                            path.move(to: CGPoint(x: 34.84 * xScale, y: 11 * yScale))
                            path.addCurve(to: CGPoint(x: 103.47 * xScale, y: 0 * yScale), control1: CGPoint(x: 46.68 * xScale, y: 3.67 * yScale), control2: CGPoint(x: 69.56 * xScale, y: 0 * yScale))
                            path.addCurve(to: CGPoint(x: 168.42 * xScale, y: 11 * yScale), control1: CGPoint(x: 137.37 * xScale, y: 0 * yScale), control2: CGPoint(x: 159.02 * xScale, y: 3.67 * yScale))
                            path.addLine(to: CGPoint(x: 170.25 * xScale, y: 42.5 * yScale))
                            path.addCurve(to: CGPoint(x: 103.47 * xScale, y: 30.5 * yScale), control1: CGPoint(x: 164.13 * xScale, y: 34.5 * yScale), control2: CGPoint(x: 141.86 * xScale, y: 30.5 * yScale))
                            path.addCurve(to: CGPoint(x: 33 * xScale, y: 43.5 * yScale), control1: CGPoint(x: 65.07 * xScale, y: 30.5 * yScale), control2: CGPoint(x: 41.58 * xScale, y: 34.83 * yScale))
                            path.addLine(to: CGPoint(x: 34.84 * xScale, y: 11 * yScale))
                            path.closeSubpath()
                        }
                    )

                // 6. Black Collar (Thin strip)
                Path { path in
                     path.move(to: CGPoint(x: 170.23 * xScale, y: 42.61 * yScale))
                     path.addCurve(to: CGPoint(x: 101.62 * xScale, y: 30.46 * yScale), control1: CGPoint(x: 170.23 * xScale, y: 39.31 * yScale), control2: CGPoint(x: 158.64 * xScale, y: 30.03 * yScale))
                     path.addCurve(to: CGPoint(x: 33.01 * xScale, y: 43.5 * yScale), control1: CGPoint(x: 44.60 * xScale, y: 30.90 * yScale), control2: CGPoint(x: 33.01 * xScale, y: 40.20 * yScale))
                     path.addCurve(to: CGPoint(x: 101.68 * xScale, y: 52.42 * yScale), control1: CGPoint(x: 33.01 * xScale, y: 46.80 * yScale), control2: CGPoint(x: 68.35 * xScale, y: 52.42 * yScale))
                     path.addCurve(to: CGPoint(x: 170.23 * xScale, y: 42.61 * yScale), control1: CGPoint(x: 135.00 * xScale, y: 52.42 * yScale), control2: CGPoint(x: 170.23 * xScale, y: 45.91 * yScale))
                     path.closeSubpath()
                }
                .fill(eraserColor)
                // 4. Dark Middle Section (Gradient part)
                Path { path in
                    path.move(to: CGPoint(x: 49.44 * xScale, y: 42.07 * yScale))
                    path.addLine(to: CGPoint(x: 49.44 * xScale, y: 84.54 * yScale))
                    path.addCurve(to: CGPoint(x: 103.98 * xScale, y: 76.19 * yScale), control1: CGPoint(x: 69.91 * xScale, y: 78.97 * yScale), control2: CGPoint(x: 88.09 * xScale, y: 76.19 * yScale))
                    path.addCurve(to: CGPoint(x: 154.45 * xScale, y: 84.95 * yScale), control1: CGPoint(x: 119.86 * xScale, y: 76.19 * yScale), control2: CGPoint(x: 136.69 * xScale, y: 79.11 * yScale))
                    path.addLine(to: CGPoint(x: 154.45 * xScale, y: 41.96 * yScale))
                    path.addCurve(to: CGPoint(x: 101.55 * xScale, y: 37.95 * yScale), control1: CGPoint(x: 141.10 * xScale, y: 39.29 * yScale), control2: CGPoint(x: 123.47 * xScale, y: 37.95 * yScale))
                    path.addCurve(to: CGPoint(x: 49.44 * xScale, y: 42.07 * yScale), control1: CGPoint(x: 79.63 * xScale, y: 37.95 * yScale), control2: CGPoint(x: 62.26 * xScale, y: 39.33 * yScale))
                    path.closeSubpath()
                }
                .fill(middleSectionGradient)
            }
        }
        .aspectRatio(200/321, contentMode: .fit)
    }
}

// Helper shape for the repeating lines pattern
struct PencilStripesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let xScale = width / 200
        let yScale = height / 321
        
        // This generates lines across the width similar to the SVG pattern
        // The original lines were rotated slightly, represented here by start/end offsets
        let numberOfLines = 40
        let spacing: CGFloat = 5.0 * xScale
        
        for i in 0..<numberOfLines {
            let xOffset = CGFloat(i) * spacing
            let startX = xOffset
            let startY: CGFloat = 0
            
            // Slight angle simulation
            let endX = startX - (2.0 * xScale)
            let endY = 62.0 * yScale
            
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
        }
        
        return path
    }
}

// Preview
struct GraphicDesignIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Standard
            KlisterCanView(bodyColor: .blue)
                .frame(width: 200)

        }
        .padding()
    }
}
