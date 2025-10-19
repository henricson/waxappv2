//
//  WaxCanGraphic.swift
//  waxappv2
//
//  Created by Herman Henriksen on 19/10/2025.
//
//  Goal:
//  - Make the lid have a shadow on the bottom side to create a 3D effect on the main body.
//  - Make the lid have a clearer gradient as if illuminated from above.
//  - Apply an illumination effect on the main body as well.

import SwiftUI

// MARK: - Split shapes

// 1) Top ellipse (lid/rim)
struct WaxCanTopEllipse: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.addEllipse(in: CGRect(x: 0, y: 0, width: width, height: 0.187610619469 * height))
        return path
    }
}

// 2) Middle band (curved side under the rim and above the body)
struct WaxCanMiddleBand: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height

        path.move(to: CGPoint(x: 0.5 * w, y: 0.187610619469 * h))
        path.addCurve(to: CGPoint(x: w, y: 0.093805309735 * h),
                      control1: CGPoint(x: 0.776142374419 * w, y: 0.187610619469 * h),
                      control2: CGPoint(x: w, y: 0.145612551681 * h))
        path.addLine(to: CGPoint(x: w, y: 0.253097345133 * h))
        path.addCurve(to: CGPoint(x: 0.5 * w, y: 0.346902654867 * h),
                      control1: CGPoint(x: w, y: 0.304904587611 * h),
                      control2: CGPoint(x: 0.776142374419 * w, y: 0.346902654867 * h))
        path.addCurve(to: CGPoint(x: 0, y: 0.253097345133 * h),
                      control1: CGPoint(x: 0.223857625116 * w, y: 0.346902654867 * h),
                      control2: CGPoint(x: 0, y: 0.304904587611 * h))
        path.addLine(to: CGPoint(x: 0, y: 0.093805309735 * h))
        path.addCurve(to: CGPoint(x: 0.5 * w, y: 0.187610619469 * h),
                      control1: CGPoint(x: 0, y: 0.145612551681 * h),
                      control2: CGPoint(x: 0.223857625116 * w, y: 0.187610619469 * h))
        path.closeSubpath()

        return path
    }
}

// 3) Main body (lower can body)
struct WaxCanBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height

        path.move(to: CGPoint(x: 0.051162790698 * w, y: 0.881415929204 * h))
        path.addLine(to: CGPoint(x: 0.051150412791 * w, y: 0.294476476106 * h))
        path.addCurve(to: CGPoint(x: 0.5 * w, y: 0.346902654867 * h),
                      control1: CGPoint(x: 0.132647113721 * w, y: 0.325532853097 * h),
                      control2: CGPoint(x: 0.30302157907 * w, y: 0.346902654867 * h))
        path.addCurve(to: CGPoint(x: 0.951162295349 * w, y: 0.29358320885 * h),
                      control1: CGPoint(x: 0.698861376744 * w, y: 0.346902654867 * h),
                      control2: CGPoint(x: 0.870607739535 * w, y: 0.325122343363 * h))
        path.addLine(to: CGPoint(x: 0.951160465116 * w, y: 0.881339823009 * h))
        path.addLine(to: CGPoint(x: 0.951162790698 * w, y: 0.881415929204 * h))
        path.addCurve(to: CGPoint(x: 0.508604362791 * w, y: 0.999984113274 * h),
                      control1: CGPoint(x: 0.951162790698 * w, y: 0.946253180531 * h),
                      control2: CGPoint(x: 0.753700218605 * w, y: 0.998936922124 * h))
        path.addLine(to: CGPoint(x: 0.501162790698 * w, y: h))
        path.addCurve(to: CGPoint(x: 0.051162790698 * w, y: 0.881415929204 * h),
                      control1: CGPoint(x: 0.252634653488 * w, y: h),
                      control2: CGPoint(x: 0.051162790698 * w, y: 0.946908102655 * h))
        path.closeSubpath()

        return path
    }
}


// MARK: - View

struct WaxCanGraphic: View {
    // Configurable styles
    var topFill: LinearGradient
    var middleFill: LinearGradient
    var bodyFill: AnyShapeStyle

    // Lighting configuration
    var bodyIllumination: LinearGradient
    var bodySpecular: LinearGradient
    init(
        // Stronger, clearer illumination on the lid (top ellipse)
        topFill: LinearGradient = LinearGradient(
            colors: [
                Color.white,                   // highlight
                Color.white.opacity(0.85),
                Color.black.opacity(0.10)      // subtle falloff
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        // Middle band: stronger definition
        middleFill: LinearGradient = LinearGradient(
            colors: [
                Color.white.opacity(0.95),
                Color.black.opacity(0.15)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        // Body base color (can be solid or gradient)
        bodyFill: some ShapeStyle = LinearGradient(
            colors: [Color.blue.opacity(0.9), Color.blue.opacity(0.65)],
            startPoint: .top,
            endPoint: .bottom
        ),

        // Body illumination: vertical soft light from top-left to bottom-right
        bodyIllumination: LinearGradient = LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(0.35), location: 0.0),
                .init(color: Color.white.opacity(0.12), location: 0.35),
                .init(color: Color.black.opacity(0.08), location: 0.9)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        // Specular highlight stripe on body
        bodySpecular: LinearGradient = LinearGradient(
            colors: [
                Color.white.opacity(0.55),
                Color.white.opacity(0.15),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        ),

    ) {
        self.topFill = topFill
        self.middleFill = middleFill
        self.bodyFill = AnyShapeStyle(bodyFill)
        self.bodyIllumination = bodyIllumination
        self.bodySpecular = bodySpecular
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width

            ZStack {
                // Base body fill
                WaxCanBody()
                    .fill(bodyFill)

                // Body illumination overlay (soft light)
                WaxCanBody()
                    .fill(bodyIllumination)
                    .blendMode(.overlay)
                    .opacity(0.75)

                // Specular highlight strip on the body (narrow band near left third)
                WaxCanBody()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .clear, location: 0.20),
                                .init(color: .white.opacity(0.55), location: 0.33),
                                .init(color: .white.opacity(0.15), location: 0.43),
                                .init(color: .clear, location: 0.55),
                                .init(color: .clear, location: 1.0)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(0.8)
                    .blendMode(.screen)

                // Middle band with stronger gradient for lid edge definition
                WaxCanMiddleBand()
                    .fill(middleFill)

                // Lid top ellipse with clearer illumination
                WaxCanTopEllipse()
                    .fill(topFill)
            }
            .frame(width: w, height: h)
            .drawingGroup() // nicer gradients/antialiasing
        }
        .frame(width: 200, height: 300)
    }
}

#Preview {

        WaxCanGraphic(
            bodyFill: LinearGradient(colors: [.blue, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
        
        )

}
