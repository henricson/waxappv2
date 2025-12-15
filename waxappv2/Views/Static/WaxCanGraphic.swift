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

// 4) Optional diagonal band (extracted from the user's MyIcon second subpath)
struct WaxCanDiagonalBand: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.size.width
        let h = rect.size.height

        path.move(to: CGPoint(x: 0.95116 * w, y: 0.29358 * h))
        path.addLine(to: CGPoint(x: 0.95116 * w, y: 0.40298 * h))
        path.addLine(to: CGPoint(x: 0.20515 * w, y: 0.97073 * h))
        path.addCurve(to: CGPoint(x: 0.05116 * w, y: 0.88142 * h),
                      control1: CGPoint(x: 0.11078 * w, y: 0.94900 * h),
                      control2: CGPoint(x: 0.05116 * w, y: 0.91704 * h))
        path.addLine(to: CGPoint(x: 0.05116 * w, y: 0.77756 * h))
        path.addLine(to: CGPoint(x: 0.62064 * w, y: 0.34415 * h))
        path.addCurve(to: CGPoint(x: 0.95116 * w, y: 0.29358 * h),
                      control1: CGPoint(x: 0.76672 * w, y: 0.33736 * h),
                      control2: CGPoint(x: 0.88746 * w, y: 0.31853 * h))
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

    // Optional band configuration
    var showBand: Bool
    var bandPrimaryColor: Color
    var bandSecondaryColor: Color?

    // Aspect ratio (width:height). Default based on prior 200x300 size -> 2:3.
    private let aspect: CGFloat = 2.0 / 3.0

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
        // Band options
        showBand: Bool = false,
        bandPrimaryColor: Color = .white,
        bandSecondaryColor: Color? = nil
    ) {
        self.topFill = topFill
        self.middleFill = middleFill
        self.bodyFill = AnyShapeStyle(bodyFill)
        self.bodyIllumination = bodyIllumination
        self.bodySpecular = bodySpecular
        self.showBand = showBand
        self.bandPrimaryColor = bandPrimaryColor
        self.bandSecondaryColor = bandSecondaryColor
    }

    var body: some View {
        GeometryReader { geo in
            // Use all available height from the parent, compute width from aspect.
            let availableHeight = geo.size.height
            let width = availableHeight * aspect

            ZStack {
                // Base body fill
                WaxCanBody()
                    .fill(bodyFill)
                
                    

                // Optional band base (prefer secondary color; fallback to primary)
                if showBand {
                    WaxCanDiagonalBand()
                        .fill(bandSecondaryColor ?? bandPrimaryColor)
                }

                // Body illumination overlay (soft light)
                WaxCanBody()
                    .fill(bodyIllumination)
                    .blendMode(.overlay)
                    .opacity(0.75)

                // If band is present, illuminate it too
                if showBand {
                    WaxCanDiagonalBand()
                        .fill(bodyIllumination)
                        .blendMode(.overlay)
                        .opacity(0.75)

                    // Specular on band: reuse the same horizontal strip idea
                    WaxCanDiagonalBand()
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
                }

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
            // Constrain content to computed width and full available height,
            // and center it horizontally within the GeometryReader width.
            .frame(width: width, height: availableHeight, alignment: .center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .drawingGroup() // nicer gradients/antialiasing
        }
        // Remove the fixed size; allow parent to dictate height.
        // You can still cap it from the outside using .frame(height: ...) where used.
    }
}

#Preview {

    VStack(spacing: 24) {
        // Parent controls height; width follows
        WaxCanGraphic(
            bodyFill: LinearGradient(colors: [.blue, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
            showBand: true,
            bandPrimaryColor: .red,
            bandSecondaryColor: .yellow
        )
        .frame(height: 300)

        WaxCanGraphic(
            bodyFill: LinearGradient(colors: [.blue, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
            showBand: true,
            bandPrimaryColor: .red
        )
        .frame(height: 220)
    }
    .padding()
}
