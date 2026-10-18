//
//  GliderGraphics.swift
//  waxappv2
//
//  Glide-wax packaging, drawn from the Pro by Swix packshots.
//
//    PS / HS   — 60 g bar in a clear clamshell with a frosted hang tab. The
//                printed card is white above and grade colour below, split
//                by a jagged mountain ridge with a slate range behind it and
//                a grey temperature disc on the ridge. About 1.8 : 1.
//    TS        — the same clamshell in its squarer 40 g size, with a
//                charcoal card instead of white. About 1.5 : 1.
//    BP        — base prep still ships in the older 180 g pack: a red head,
//                a black stripe slanting up to the right, and the grade
//                colour below. About 2.5 : 1.
//    HS Liquid — a slim 125 ml aerosol with a white dome overcap, white can
//                and the same ridge round the foot. About 3.6 : 1.
//    TSP       — a tall powder canister with a flat white cap, the card
//                fading from white into the grade colour. About 2.85 : 1.
//

import SwiftUI

// MARK: - Pro clamshell

/// Clear plastic clamshell, including the hang tab at the top.
nonisolated struct ProCaseOutline: Shape {
  var tabDepth: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addRoundedRect(
      in: CGRect(origin: rect.unit(0, tabDepth * 0.8), size: CGSize(width: rect.width, height: (1 - tabDepth * 0.8) * rect.height)),
      cornerSize: CGSize(width: 0.075 * rect.width, height: 0.075 * rect.width),
      style: .continuous
    )
    // Hang tab: a shallow rounded trapezoid.
    var tab = Path()
    tab.move(to: rect.unit(0.20, tabDepth))
    tab.addLine(to: rect.unit(0.27, 0.004))
    tab.addLine(to: rect.unit(0.73, 0.004))
    tab.addLine(to: rect.unit(0.80, tabDepth))
    tab.closeSubpath()
    path.addPath(tab.strokedPath(StrokeStyle(lineWidth: 0.02 * rect.width, lineJoin: .round)))
    path.addPath(tab)
    return path
  }
}

/// The oval euro slot punched through the tab.
nonisolated struct ProCaseSlot: Shape {
  var tabDepth: CGFloat

  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addRoundedRect(
      in: CGRect(origin: rect.unit(0.37, tabDepth * 0.30), size: CGSize(width: 0.26 * rect.width, height: tabDepth * 0.38 * rect.height)),
      cornerSize: CGSize(width: tabDepth * 0.19 * rect.height, height: tabDepth * 0.19 * rect.height)
    )
    return path
  }
}

/// The printed card inside the case.
nonisolated struct ProCaseCard: Shape {
  var tabDepth: CGFloat

  func path(in rect: CGRect) -> Path {
    let inset = 0.075
    var path = Path()
    path.addRoundedRect(
      in: CGRect(
        origin: rect.unit(inset, tabDepth + 0.025),
        size: CGSize(width: (1 - 2 * inset) * rect.width, height: (1 - tabDepth - 0.050) * rect.height)),
      cornerSize: CGSize(width: 0.035 * rect.width, height: 0.035 * rect.width),
      style: .continuous
    )
    return path
  }
}

/// Shared clamshell: case, tab, card and wax edge. `print` is laid out in
/// the full drawing's coordinates.
private struct ProClamshell<Print: View>: View {
  var aspect: CGFloat
  var tabDepth: CGFloat
  var cardColor: Color
  var waxColor: Color
  @ViewBuilder var print: (CGSize) -> Print

  var body: some View {
    ContainerCanvas(aspect: aspect, baseline: 0.965) { size in
      let line = size.height * 0.004

      ZStack(alignment: .topLeading) {
        // Clear case, read as a cool frosted rim against any background.
        ProCaseOutline(tabDepth: tabDepth)
          .fill(LinearGradient(
            colors: [Color(white: 0.94), Color(white: 0.84)],
            startPoint: .topLeading, endPoint: .bottomTrailing))

        // The wax bar shows through the clear case, faintly tinting it.
        ProCaseOutline(tabDepth: tabDepth)
          .fill(waxColor.opacity(0.10))

        ProCaseCard(tabDepth: tabDepth).fill(cardColor)
        print(size)
          .frame(width: size.width, height: size.height, alignment: .topLeading)
          .mask(ProCaseCard(tabDepth: tabDepth))
        ProCaseCard(tabDepth: tabDepth).flatLit()
        ProCaseCard(tabDepth: tabDepth).stroke(.black.opacity(0.14), lineWidth: line)

        // Moulded plastic takes a hard streak, not a soft curve.
        ProCaseOutline(tabDepth: tabDepth)
          .fill(ContainerLight.plasticSheen)
          .blendMode(.screen)
          .opacity(0.8)
        ProCaseOutline(tabDepth: tabDepth).stroke(.black.opacity(0.16), lineWidth: line)
        ProCaseOutline(tabDepth: tabDepth).stroke(.white.opacity(0.55), lineWidth: line * 0.6)

        ProCaseSlot(tabDepth: tabDepth).fill(Color(white: 0.62))
        ProCaseSlot(tabDepth: tabDepth).stroke(.black.opacity(0.20), lineWidth: line * 0.8)
      }
      .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
  }
}

/// The white or charcoal Pro card: ridge, slate range, disc and code.
private struct ProCardPrint: View {
  var size: CGSize
  var gradeColor: Color
  var ridgeTop: CGFloat
  var code: String
  var letterColor: Color

  var body: some View {
    ZStack(alignment: .topLeading) {
      SwixRidge(top: ridgeTop - 0.020, depth: 0.15, isBackdrop: true)
        .fill(Color(red: 0.42, green: 0.45, blue: 0.50))
      SwixRidge(top: ridgeTop, depth: 0.15)
        .fill(gradeColor)
      SwixRidge(top: ridgeTop, depth: 0.15)
        .stroke(.white.opacity(0.85), lineWidth: size.height * 0.004)

      if PrintDetail.showsFineDetail(height: size.height) {
        TemperatureDisc(diameter: size.width * 0.24)
          .position(x: size.width * 0.27, y: size.height * (ridgeTop + 0.10))
      }

      if PrintDetail.showsText(height: size.height) {
        let parts = PrintedCode.split(code)
        PrintedCode(
          letters: parts.letters, digits: parts.digits,
          size: size.width * 0.40, letterColor: letterColor, digitColor: gradeColor
        )
        .position(x: size.width * 0.50, y: size.height * (ridgeTop - 0.14))
      }
    }
  }
}

/// PS and HS: white card, 60 g.
struct GlideBlockGraphic: View {
  var bodyColor: Color
  var bandColor: Color?
  var code: String = ""

  var body: some View {
    ProClamshell(aspect: 0.55, tabDepth: 0.080, cardColor: Color(white: 0.975), waxColor: bodyColor) { size in
      ProCardPrint(
        size: size, gradeColor: bodyColor, ridgeTop: 0.585, code: code,
        letterColor: Color(red: 0.50, green: 0.53, blue: 0.57))
    }
  }
}

/// TS Black: charcoal card, squarer 40 g.
struct GlideBlackGraphic: View {
  var gradeColor: Color
  var code: String = ""

  var body: some View {
    ProClamshell(aspect: 0.67, tabDepth: 0.100, cardColor: Color(red: 0.29, green: 0.30, blue: 0.33), waxColor: Color(white: 0.12)) { size in
      ProCardPrint(size: size, gradeColor: gradeColor, ridgeTop: 0.600, code: code, letterColor: .white)
    }
  }
}

// MARK: - Base prep

/// Older full-colour 180 g pack: red head, black slanted stripe, grade body.
struct GlideBasePrepGraphic: View {
  var bodyColor: Color
  var code: String = ""

  static let headRed = Color(red: 0.84, green: 0.15, blue: 0.17)

  var body: some View {
    ProClamshell(aspect: 0.40, tabDepth: 0.030, cardColor: bodyColor, waxColor: bodyColor) { size in
      ZStack(alignment: .topLeading) {
        Rectangle().fill(Self.headRed)
          .frame(width: size.width, height: size.height * 0.215)
        DiagonalBand(left: 0.245, right: 0.185, thickness: 0.035).fill(Color(white: 0.08))

        if PrintDetail.showsText(height: size.height) {
          let parts = PrintedCode.split(code)
          PrintedCode(
            letters: parts.letters, digits: parts.digits,
            size: size.width * 0.34, letterColor: .white, italic: true
          )
          .position(x: size.width * 0.50, y: size.height * 0.38)
        }
      }
    }
  }
}

// MARK: - HS Liquid aerosol

nonisolated struct AerosolCan: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.unit(0.0, 0.215))
    path.addLine(to: rect.unit(0.0, 0.975))
    path.addQuadCurve(to: rect.unit(0.08, 1.0), control: rect.unit(0.0, 1.0))
    path.addLine(to: rect.unit(0.92, 1.0))
    path.addQuadCurve(to: rect.unit(1.0, 0.975), control: rect.unit(1.0, 1.0))
    path.addLine(to: rect.unit(1.0, 0.215))
    path.closeSubpath()
    return path
  }
}

/// Dome overcap, same diameter as the can.
nonisolated struct AerosolCap: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.unit(0.0, 0.225))
    path.addLine(to: rect.unit(0.0, 0.070))
    path.addCurve(
      to: rect.unit(1.0, 0.070),
      control1: rect.unit(0.0, -0.020),
      control2: rect.unit(1.0, -0.020))
    path.addLine(to: rect.unit(1.0, 0.225))
    path.closeSubpath()
    return path
  }
}

struct GlideLiquidGraphic: View {
  var bodyColor: Color
  var labelColor: Color?
  var code: String = ""

  var body: some View {
    ContainerCanvas(aspect: 0.28, baseline: 0.975) { size in
      let line = size.height * 0.003

      ZStack(alignment: .topLeading) {
        AerosolCan().fill(Color(white: 0.975))
        ZStack(alignment: .topLeading) {
          SwixRidge(top: 0.630, depth: 0.075, isBackdrop: true)
            .fill(Color(red: 0.42, green: 0.45, blue: 0.50))
          SwixRidge(top: 0.640, depth: 0.075).fill(bodyColor)
          SwixRidge(top: 0.640, depth: 0.075)
            .stroke(.white.opacity(0.85), lineWidth: size.height * 0.003)

          if PrintDetail.showsText(height: size.height) {
            let parts = PrintedCode.split(code)
            PrintedCode(
              letters: parts.letters, digits: parts.digits,
              size: size.width * 0.40,
              letterColor: Color(red: 0.50, green: 0.53, blue: 0.57), digitColor: bodyColor
            )
            .position(x: size.width * 0.50, y: size.height * 0.53)
          }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .mask(AerosolCan())
        AerosolCan().cylinderLit()
        AerosolCan().stroke(.black.opacity(0.16), lineWidth: line)

        AerosolCap().fill(Color(white: 0.985))
        AerosolCap().cylinderLit()
        AerosolCap().fill(ContainerLight.plasticSheen).blendMode(.screen).opacity(0.6)
        AerosolCap().stroke(.black.opacity(0.18), lineWidth: line)
      }
      .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
  }
}

// MARK: - TSP powder canister

nonisolated struct PowderCanister: Shape {
  func path(in rect: CGRect) -> Path {
    CylinderSide(left: 0.03, right: 0.97, top: 0.095, bottom: 0.978, rim: 0.016)
      .path(in: rect)
  }
}

/// Flat screw cap and its top face, on the same rim ellipse as the foot.
nonisolated enum PowderCapGeometry {
  static let side = CylinderSide(left: 0.0, right: 1.0, top: 0.024, bottom: 0.105, rim: 0.016)
  static let face = CylinderTop(left: 0.0, right: 1.0, top: 0.024, rim: 0.016)
}

struct GlidePowderGraphic: View {
  /// Grade colour of the printed card.
  var gradeColor: Color
  var code: String = ""

  var body: some View {
    ContainerCanvas(aspect: 0.35, baseline: 0.975) { size in
      let line = size.height * 0.003

      ZStack(alignment: .topLeading) {
        PowderCanister().fill(Color(white: 0.975))
        ZStack(alignment: .topLeading) {
          // The card fades from white into the grade colour.
          LinearGradient(
            stops: [
              .init(color: .clear, location: 0.40),
              .init(color: gradeColor.opacity(0.55), location: 0.72),
            ],
            startPoint: .top, endPoint: .bottom)
          SwixRidge(top: 0.680, depth: 0.070).fill(gradeColor)
          SwixRidge(top: 0.680, depth: 0.070)
            .stroke(.white.opacity(0.85), lineWidth: size.height * 0.003)

          if PrintDetail.showsText(height: size.height) {
            let parts = PrintedCode.split(code)
            PrintedCode(
              letters: parts.letters, digits: parts.digits,
              size: size.width * 0.34,
              letterColor: Color(red: 0.50, green: 0.53, blue: 0.57), digitColor: gradeColor
            )
            .position(x: size.width * 0.50, y: size.height * 0.45)
          }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .mask(PowderCanister())
        PowderCanister().cylinderLit()
        PowderCanister().stroke(.black.opacity(0.16), lineWidth: line)

        PowderCapGeometry.side.fill(Color(white: 0.985))
        PowderCapGeometry.side.lidLit()
        PowderCapGeometry.side.stroke(.black.opacity(0.18), lineWidth: line)
        PowderCapGeometry.face.fill(LinearGradient(colors: [.white, Color(white: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing))
        PowderCapGeometry.face.stroke(.black.opacity(0.10), lineWidth: line)
      }
      .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
  }
}

// MARK: - Unified icon

/// One entry point that draws the right container for any product.
struct WaxIcon: View {
  let product: WaxProduct

  private var primary: Color { Color(hex: product.primaryColor) ?? .gray }
  private var secondary: Color? { product.secondaryColor.flatMap { Color(hex: $0) } }

  var body: some View {
    switch (product.brand, product.seriesCode) {
    case (.rode, "K"):
      RodeKlisterView(gradeColor: primary, accentColor: secondary, code: product.code)
    case (.rode, _):
      RodeCanGraphic(gradeColor: primary, code: product.code)

    case (.swix, "VP"):
      WaxCanVPGraphic(gradeColor: secondary ?? primary, code: product.code)
    case (.swix, "KN"):
      KlisterNeroView(accentColor: secondary ?? primary, code: product.code)
    case (.swix, "K"):
      KlisterUniversalView(stripeColor: secondary, code: product.code)
    case (.swix, "KX"):
      // KX20 is a base klister, but it ships in the same tube.
      KlisterCanView(bodyColor: primary, labelColor: secondary, code: product.code)

    case (.swix, "TS"):
      GlideBlackGraphic(gradeColor: secondary ?? primary, code: product.code)
    case (.swix, "BP"):
      GlideBasePrepGraphic(bodyColor: primary, code: product.code)

    default:
      switch product.kind {
      case .klister:
        KlisterCanView(bodyColor: primary, labelColor: secondary, code: product.code)
      case .glideHot, .glideBase:
        GlideBlockGraphic(bodyColor: primary, bandColor: secondary, code: product.code)
      case .glideLiquid:
        GlideLiquidGraphic(bodyColor: primary, labelColor: secondary, code: product.code)
      case .glidePowder:
        GlidePowderGraphic(gradeColor: primary, code: product.code)
      case .hardwax, .binder:
        WaxCanGraphic(bodyColor: primary, bandColor: secondary, code: product.code)
      }
    }
  }
}

extension WaxIcon {
  /// Width ÷ height of the container drawn for a product, so layouts can
  /// size a row of mixed containers without guessing.
  static func aspect(for product: WaxProduct) -> CGFloat {
    switch (product.brand, product.seriesCode) {
    case (.rode, "K"): return 0.29
    case (.rode, _): return TinGeometry.aspect
    case (.swix, "KN"), (.swix, "K"), (.swix, "KX"): return 0.33
    case (.swix, "TS"): return 0.67
    case (.swix, "BP"): return 0.40
    case (.swix, "VP"): return TinGeometry.aspect
    default:
      switch product.kind {
      case .klister: return 0.33
      case .glideHot, .glideBase: return 0.55
      case .glideLiquid: return 0.28
      case .glidePowder: return 0.35
      case .hardwax, .binder: return TinGeometry.aspect
      }
    }
  }

  /// Rough real height relative to a 45 g tin, for arranging products on a
  /// shelf. Exact scale would leave the tin tiny next to an aerosol, so the
  /// spread is compressed but the order is kept.
  static func shelfHeight(for product: WaxProduct) -> CGFloat {
    switch product.kind {
    case .hardwax: return 0.78
    case .klister, .binder: return product.brand == .rode ? 1.0 : 0.96
    case .glideHot, .glideBase: return product.seriesCode == "TS" ? 0.74 : 0.9
    case .glideLiquid: return 1.0
    case .glidePowder: return 0.92
    }
  }
}

// MARK: - Previews

#Preview("Gliders") {
  HStack(alignment: .bottom, spacing: 16) {
    GlideBlockGraphic(bodyColor: Color(hex: "#2C68BD")!, code: "PS6")
    GlideBlackGraphic(gradeColor: Color(hex: "#D23A2B")!, code: "TS8")
    GlideBasePrepGraphic(bodyColor: Color(hex: "#6A3F9E")!, code: "BP77")
    GlideLiquidGraphic(bodyColor: Color(hex: "#D23A2B")!, code: "HS8L")
    GlidePowderGraphic(gradeColor: Color(hex: "#D23A2B")!, code: "TSP8")
  }
  .frame(height: 220)
  .padding()
}
