//
//  ContainerStyling.swift
//  waxappv2
//
//  The shared lighting model for every wax container the app draws.
//
//  One key light from the upper left, a cool fill from the right, contact
//  shadow on the ground, and a thin rim light so the silhouette survives on
//  both light and dark backgrounds. Keeping it in one place is what makes a
//  tin, a tube, a bar and a jar look like they were photographed together.
//

import SwiftUI

nonisolated enum ContainerLight {

  // MARK: - Round bodies
  //
  // Shadow and highlight are separate passes — one multiplied, one screened.
  // A single overlay gradient carrying both black and white stops washes a
  // mid-tone body out to grey instead of making it look round.

  /// Core shadow across a cylinder, multiplied over the body colour.
  static let cylinderShadow = LinearGradient(
    stops: [
      .init(color: .black.opacity(0.44), location: 0.000),
      .init(color: .black.opacity(0.20), location: 0.065),
      .init(color: .black.opacity(0.04), location: 0.160),
      .init(color: .clear, location: 0.260),
      .init(color: .clear, location: 0.620),
      .init(color: .black.opacity(0.10), location: 0.790),
      .init(color: .black.opacity(0.30), location: 0.910),
      .init(color: .black.opacity(0.44), location: 0.975),
      .init(color: .black.opacity(0.26), location: 1.000),
    ],
    startPoint: .leading,
    endPoint: .trailing
  )

  /// Specular core plus a rim light, screened over the body colour.
  static let cylinderHighlight = LinearGradient(
    stops: [
      .init(color: .clear, location: 0.000),
      .init(color: .clear, location: 0.185),
      .init(color: .white.opacity(0.26), location: 0.262),
      .init(color: .white.opacity(0.60), location: 0.312),
      .init(color: .white.opacity(0.22), location: 0.372),
      .init(color: .clear, location: 0.470),
      .init(color: .clear, location: 0.920),
      .init(color: .white.opacity(0.34), location: 0.972),
      .init(color: .clear, location: 1.000),
    ],
    startPoint: .leading,
    endPoint: .trailing
  )

  /// Ambient occlusion down the length of a body: under the lid overhang,
  /// and again where it meets the ground.
  static let verticalShadow = LinearGradient(
    stops: [
      .init(color: .black.opacity(0.26), location: 0.00),
      .init(color: .black.opacity(0.07), location: 0.055),
      .init(color: .clear, location: 0.150),
      .init(color: .clear, location: 0.820),
      .init(color: .black.opacity(0.09), location: 0.940),
      .init(color: .black.opacity(0.24), location: 1.000),
    ],
    startPoint: .top,
    endPoint: .bottom
  )

  // MARK: - Flat bodies

  /// Shading for the front face of a flat pack: lit down one diagonal.
  static let flatShadow = LinearGradient(
    stops: [
      .init(color: .clear, location: 0.00),
      .init(color: .clear, location: 0.45),
      .init(color: .black.opacity(0.08), location: 0.75),
      .init(color: .black.opacity(0.20), location: 1.00),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let flatHighlight = LinearGradient(
    stops: [
      .init(color: .white.opacity(0.34), location: 0.00),
      .init(color: .white.opacity(0.08), location: 0.26),
      .init(color: .clear, location: 0.50),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// A single hard streak, the way light reads on clear moulded plastic.
  static let plasticSheen = LinearGradient(
    stops: [
      .init(color: .clear, location: 0.00),
      .init(color: .clear, location: 0.17),
      .init(color: .white.opacity(0.62), location: 0.252),
      .init(color: .white.opacity(0.12), location: 0.315),
      .init(color: .clear, location: 0.40),
      .init(color: .clear, location: 0.80),
      .init(color: .white.opacity(0.26), location: 0.870),
      .init(color: .clear, location: 0.935),
    ],
    startPoint: .leading,
    endPoint: .trailing
  )

  /// Top surfaces take the key light almost head-on.
  static let topFace = LinearGradient(
    colors: [.white.opacity(0.70), .white.opacity(0.26)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  /// Receding faces, kept dark so depth reads at a glance.
  static let sideFace = LinearGradient(
    colors: [.black.opacity(0.16), .black.opacity(0.36)],
    startPoint: .top,
    endPoint: .bottom
  )
}

/// Applies the round-body lighting passes to any shape in the right order.
extension Shape {
  @ViewBuilder
  func cylinderLit() -> some View {
    ZStack {
      fill(ContainerLight.cylinderShadow).blendMode(.multiply)
      fill(ContainerLight.cylinderHighlight).blendMode(.screen)
      fill(ContainerLight.verticalShadow).blendMode(.multiply)
    }
  }

  @ViewBuilder
  func flatLit() -> some View {
    ZStack {
      fill(ContainerLight.flatShadow).blendMode(.multiply)
      fill(ContainerLight.flatHighlight).blendMode(.screen)
    }
  }
}

// MARK: - Contact shadow

/// A soft ellipse on the ground beneath a container.
///
/// Objects without one look like stickers; this is the single cheapest thing
/// that makes the set feel photographed.
struct ContainerContactShadow: View {
  var width: CGFloat
  var height: CGFloat

  var body: some View {
    Ellipse()
      .fill(
        RadialGradient(
          stops: [
            .init(color: .black.opacity(0.34), location: 0.0),
            .init(color: .black.opacity(0.16), location: 0.55),
            .init(color: .clear, location: 1.0),
          ],
          center: .center,
          startRadius: 0,
          endRadius: width / 2
        )
      )
      .frame(width: width, height: height)
      .blur(radius: height * 0.28)
      .allowsHitTesting(false)
  }
}

extension View {
  /// Grounds a container with a contact shadow sitting at `baseline`
  /// (a fraction of the drawing height).
  func containerContactShadow(
    side: CGFloat,
    width: CGFloat,
    baseline: CGFloat
  ) -> some View {
    background(alignment: .top) {
      ContainerContactShadow(width: width * 0.96, height: side * 0.075)
        .offset(y: side * baseline)
    }
  }
}

// MARK: - Canvas

/// Lays a container out at its real proportions inside whatever frame it is
/// given, standing on the bottom edge the way a product sits on a shelf.
///
/// Every container used to be squeezed into the same 2:3 box, which made a
/// slim klister tube as fat as a wax tin and a flat glide pack as tall as
/// either. `aspect` is width ÷ height of the real article.
struct ContainerCanvas<Content: View>: View {
  let aspect: CGFloat
  /// Where the contact shadow sits, as a fraction of the drawing height.
  var baseline: CGFloat = 0.955
  @ViewBuilder var content: (CGSize) -> Content

  var body: some View {
    GeometryReader { geo in
      let height = min(geo.size.height, geo.size.width / aspect)
      let size = CGSize(width: height * aspect, height: height)

      content(size)
        .frame(width: size.width, height: size.height)
        .compositingGroup()
        .containerContactShadow(side: height, width: size.width, baseline: baseline)
        .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
    }
  }
}

nonisolated extension CGRect {
  /// A point given as fractions of the rect.
  func unit(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: minX + x * width, y: minY + y * height)
  }
}

// MARK: - Printed details

/// Print appears only once the artwork is large enough to read it. At list
/// size it would be noise, and the code is always captioned alongside.
nonisolated enum PrintDetail {
  static func showsText(height: CGFloat) -> Bool { height >= 110 }
  static func showsFineDetail(height: CGFloat) -> Bool { height >= 44 }
}

/// The jagged mountain ridge that runs across every current Pro by Swix
/// label, filled down to the bottom of the rect.
///
/// `top` is where the highest peak sits and `depth` how far the valleys
/// drop below it, both as fractions of the rect height.
nonisolated struct SwixRidge: Shape {
  var top: CGFloat
  var depth: CGFloat
  /// The grey backdrop range uses a different skyline from the front one.
  var isBackdrop = false

  private static let front: [(CGFloat, CGFloat)] = [
    (0.00, 0.62), (0.16, 0.40), (0.27, 0.55), (0.44, 0.22), (0.60, 0.00),
    (0.71, 0.34), (0.79, 0.46), (0.89, 0.18), (1.00, 0.50),
  ]
  /// Peaks sit in the front range's valleys, so the grey shows between them.
  private static let back: [(CGFloat, CGFloat)] = [
    (0.00, 0.75), (0.12, 0.55), (0.26, 0.30), (0.38, 0.62), (0.55, 0.50),
    (0.70, 0.28), (0.78, 0.10), (0.88, 0.45), (1.00, 0.62),
  ]

  func path(in rect: CGRect) -> Path {
    let profile = isBackdrop ? Self.back : Self.front
    var path = Path()
    path.move(to: rect.unit(0, 1))
    for (x, y) in profile {
      path.addLine(to: rect.unit(x, top + y * depth))
    }
    path.addLine(to: rect.unit(1, 1))
    path.closeSubpath()
    return path
  }
}

/// A band rising across the rect from lower left to upper right: the
/// signature diagonal on Swix tins and classic klister tubes.
///
/// `left` and `right` are the band's upper edge where it meets each side;
/// `thickness` is measured vertically. All in fractions of the rect height.
nonisolated struct DiagonalBand: Shape {
  var left: CGFloat
  var right: CGFloat
  var thickness: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.unit(-0.05, left + 0.05 * (left - right)))
    path.addLine(to: rect.unit(1.05, right - 0.05 * (left - right)))
    path.addLine(to: rect.unit(1.05, right - 0.05 * (left - right) + thickness))
    path.addLine(to: rect.unit(-0.05, left + 0.05 * (left - right) + thickness))
    path.closeSubpath()
    return path
  }

  /// The band's angle on screen, for setting print along it.
  static func angle(left: CGFloat, right: CGFloat, in size: CGSize) -> Angle {
    .radians(atan2((right - left) * size.height, size.width))
  }
}

/// The grey temperature disc that sits on the ridge of Pro packs.
struct TemperatureDisc: View {
  var diameter: CGFloat

  var body: some View {
    Circle()
      .fill(Color(red: 0.55, green: 0.58, blue: 0.62))
      .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: diameter * 0.07))
      .frame(width: diameter, height: diameter)
  }
}

/// A product code set the way the packs print it: a heavy, tight face, with
/// the grade digits optionally picked out in a second colour.
struct PrintedCode: View {
  var letters: String
  var digits: String = ""
  var size: CGFloat
  var letterColor: Color
  var digitColor: Color? = nil
  var italic = false

  var body: some View {
    HStack(alignment: .lastTextBaseline, spacing: size * 0.02) {
      Text(verbatim: letters)
        .foregroundStyle(letterColor)
      if !digits.isEmpty {
        Text(verbatim: digits)
          .foregroundStyle(digitColor ?? letterColor)
      }
    }
    .font(.system(size: size, weight: .heavy).width(.condensed))
    .italic(italic)
    .kerning(-size * 0.03)
    .lineLimit(1)
    .fixedSize()
    .accessibilityHidden(true)
  }

  /// Splits "HS10L" into ("HS", "10L") and "KX45N" into ("KX", "45N"):
  /// the series letters, then the grade and any suffix.
  static func split(_ code: String) -> (letters: String, digits: String) {
    let letters = String(code.prefix { $0.isLetter })
    return (letters, String(code.dropFirst(letters.count)))
  }
}

// MARK: - Cylinders seen slightly from above

/// The visible side of a short cylinder — a lid skirt or a cap — between two
/// heights. Both rims are drawn as ellipses of half-height `rim`, so the top
/// meets a `CylinderTop` exactly and the lower edge curves with perspective
/// instead of cutting straight across.
nonisolated struct CylinderSide: Shape {
  var left: CGFloat
  var right: CGFloat
  var top: CGFloat
  var bottom: CGFloat
  var rim: CGFloat

  func path(in rect: CGRect) -> Path {
    // 4/3 of the rim depth puts a cubic's midpoint on the ellipse.
    let bulge = rim * 4 / 3
    var path = Path()
    path.move(to: rect.unit(left, top))
    path.addLine(to: rect.unit(left, bottom))
    path.addCurve(
      to: rect.unit(right, bottom),
      control1: rect.unit(left, bottom + bulge),
      control2: rect.unit(right, bottom + bulge))
    path.addLine(to: rect.unit(right, top))
    path.addCurve(
      to: rect.unit(left, top),
      control1: rect.unit(right, top - bulge),
      control2: rect.unit(left, top - bulge))
    path.closeSubpath()
    return path
  }
}

/// The ellipse you look down on at the top of a `CylinderSide`.
nonisolated struct CylinderTop: Shape {
  var left: CGFloat
  var right: CGFloat
  var top: CGFloat
  var rim: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addEllipse(
      in: CGRect(
        origin: rect.unit(left, top - rim),
        size: CGSize(width: (right - left) * rect.width, height: 2 * rim * rect.height)))
    return path
  }
}

/// A curved band hanging under a cylinder's lower rim, for the shadow a lid
/// casts on the body below it.
nonisolated struct CylinderRimShadow: Shape {
  var left: CGFloat
  var right: CGFloat
  var rimY: CGFloat
  var rim: CGFloat
  var depth: CGFloat

  func path(in rect: CGRect) -> Path {
    let bulge = rim * 4 / 3
    var path = Path()
    path.move(to: rect.unit(left, rimY - 0.01))
    path.addLine(to: rect.unit(right, rimY - 0.01))
    path.addLine(to: rect.unit(right, rimY + depth))
    path.addCurve(
      to: rect.unit(left, rimY + depth),
      control1: rect.unit(right, rimY + depth + bulge),
      control2: rect.unit(left, rimY + depth + bulge))
    path.closeSubpath()
    return path
  }
}

extension Shape {
  /// Lighting for a short cylinder such as a lid: round across, with only a
  /// little occlusion at its lower edge. The tall-body pass darkens the top
  /// too, which on a lid shows as a grey sliver above the top ellipse.
  @ViewBuilder
  func lidLit() -> some View {
    ZStack {
      fill(ContainerLight.cylinderShadow).blendMode(.multiply).opacity(0.75)
      fill(ContainerLight.cylinderHighlight).blendMode(.screen)
      fill(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0.55),
            .init(color: .black.opacity(0.16), location: 1.0),
          ],
          startPoint: .top, endPoint: .bottom)
      )
      .blendMode(.multiply)
    }
  }
}
