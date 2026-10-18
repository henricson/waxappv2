//
//  KlisterCanGraphic.swift
//  waxappv2
//
//  Klister tubes, drawn from the manufacturers' packshots. Both brands
//  photograph the tube standing on its cap, crimped seam up, so that is how
//  they are drawn here.
//
//  Swix KX:  aluminium tube printed in the grade colour, with the classic
//            diagonal "X" in the second colour
//            and a black knurled cap about half the tube's width.
//  Swix KN:  "Nero" — a black tube with a big crossed X of two colours.
//  Swix K:   universal klister in a silver tube with a red diagonal.
//  Rode:     glossy tube in the grade colour, white crimp band, white cap,
//            and a white label band with the blue snowflake badge.
//
//  A 55–60 g tube is roughly three times as tall as it is wide.
//

import SwiftUI

// MARK: - Geometry

/// Body outline: full width at the crimp, tapering gently towards the
/// shoulder, then one continuous sweep in to the neck.
nonisolated struct KlisterTubeBody: Shape {
  var neckWidth: CGFloat = 0.54

  func path(in rect: CGRect) -> Path {
    let neckL = 0.5 - neckWidth / 2
    let neckR = 0.5 + neckWidth / 2

    var path = Path()
    path.move(to: rect.unit(0.015, 0.045))
    path.addLine(to: rect.unit(0.985, 0.045))
    path.addLine(to: rect.unit(0.925, 0.780))
    path.addCurve(
      to: rect.unit(neckR, 0.862),
      control1: rect.unit(0.915, 0.830),
      control2: rect.unit(neckR + 0.10, 0.850))
    path.addLine(to: rect.unit(neckL, 0.862))
    path.addCurve(
      to: rect.unit(0.075, 0.780),
      control1: rect.unit(neckL - 0.10, 0.850),
      control2: rect.unit(0.085, 0.830))
    path.closeSubpath()
    return path
  }
}

/// The flattened, folded seam at the top of the tube.
nonisolated struct KlisterTubeCrimp: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addRoundedRect(
      in: CGRect(origin: rect.unit(0.0, 0.0), size: CGSize(width: rect.width, height: 0.062 * rect.height)),
      cornerSize: CGSize(width: 0.05 * rect.width, height: 0.05 * rect.width)
    )
    return path
  }
}

/// A single crease pressed across the seam.
nonisolated struct KlisterCrimpCrease: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.unit(0.04, 0.040))
    path.addLine(to: rect.unit(0.96, 0.040))
    return path
  }
}

nonisolated struct KlisterTubeCap: Shape {
  var width: CGFloat = 0.56

  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addRoundedRect(
      in: CGRect(
        origin: rect.unit(0.5 - width / 2, 0.850),
        size: CGSize(width: width * rect.width, height: 0.148 * rect.height)),
      cornerSize: CGSize(width: 0.06 * rect.width, height: 0.06 * rect.width),
      style: .continuous
    )
    return path
  }
}

/// Knurling on the cap, only drawn once the cap is big enough to show it.
nonisolated struct KlisterCapKnurl: Shape {
  var width: CGFloat = 0.56

  func path(in rect: CGRect) -> Path {
    var path = Path()
    let count = 9
    let left = 0.5 - width / 2 + 0.05
    let right = 0.5 + width / 2 - 0.05
    for index in 0..<count {
      let x = left + (right - left) * CGFloat(index) / CGFloat(count - 1)
      path.move(to: rect.unit(x, 0.868))
      path.addLine(to: rect.unit(x, 0.982))
    }
    return path
  }
}

// MARK: - Shared tube

private struct KlisterTube<Print: View>: View {
  var tubeColor: Color
  var crimpColor: Color
  var capColor: Color
  var aspect: CGFloat = 0.33
  var glossy = false
  @ViewBuilder var print: (CGSize) -> Print

  var body: some View {
    ContainerCanvas(aspect: aspect, baseline: 0.965) { size in
      let line = size.height * 0.0035

      ZStack(alignment: .topLeading) {
        KlisterTubeBody().fill(tubeColor)
        print(size)
          .frame(width: size.width, height: size.height, alignment: .topLeading)
          .mask(KlisterTubeBody())
        KlisterTubeBody().cylinderLit()
        if glossy {
          // Gloss lacquer catches a second, sharper streak.
          KlisterTubeBody().fill(ContainerLight.plasticSheen).blendMode(.screen).opacity(0.7)
        }
        KlisterTubeBody().stroke(.black.opacity(0.20), lineWidth: line)

        KlisterTubeCrimp().fill(crimpColor)
        KlisterTubeCrimp().flatLit()
        KlisterCrimpCrease().stroke(.black.opacity(0.18), lineWidth: line)
        KlisterTubeCrimp().stroke(.black.opacity(0.20), lineWidth: line)

        KlisterTubeCap().fill(capColor)
        KlisterTubeCap().cylinderLit()
        if PrintDetail.showsFineDetail(height: size.height) {
          KlisterCapKnurl()
            .stroke(capColor.isLight ? .black.opacity(0.10) : .white.opacity(0.10), lineWidth: line)
        }
        KlisterTubeCap().stroke(.black.opacity(0.30), lineWidth: line)
      }
      .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
  }
}

/// Code set up the tube the way Swix prints it, reading bottom to top.
private struct TubeCode: View {
  var code: String
  var size: CGSize
  var color: Color
  var digitColor: Color? = nil

  var body: some View {
    let parts = PrintedCode.split(code)
    PrintedCode(
      letters: parts.letters, digits: parts.digits,
      size: size.width * 0.40, letterColor: color, digitColor: digitColor, italic: true
    )
    .rotationEffect(.degrees(-90))
    .position(x: size.width * 0.50, y: size.height * 0.30)
  }
}

// MARK: - Swix KX

struct KlisterCanView: View {
  /// Grade colour: the tube itself.
  var bodyColor: Color
  var labelColor: Color?
  var code: String = ""

  var body: some View {
    KlisterTube(tubeColor: bodyColor, crimpColor: bodyColor, capColor: Color(white: 0.10)) { size in
      let accent = labelColor ?? .white.opacity(0.7)
      ZStack(alignment: .topLeading) {
        // The big X: a broad stroke rising to the right, crossed low down
        // by a narrower one falling to the right.
        DiagonalBand(left: 0.64, right: 0.30, thickness: 0.085).fill(accent)
        DiagonalBand(left: 0.42, right: 0.66, thickness: 0.050).fill(accent)

        if PrintDetail.showsText(height: size.height) {
          TubeCode(code: code, size: size, color: bodyColor.isLight ? .black.opacity(0.8) : .white, digitColor: accent)
        }
      }
    }
  }
}

// MARK: - Swix KN Nero

struct KlisterNeroView: View {
  var accentColor: Color
  var code: String = ""

  static let crossBlue = Color(red: 0.24, green: 0.45, blue: 0.88)

  var body: some View {
    KlisterTube(tubeColor: Color(white: 0.09), crimpColor: Color(white: 0.12), capColor: Color(white: 0.09)) { size in
      ZStack(alignment: .topLeading) {
        DiagonalBand(left: 0.68, right: 0.40, thickness: 0.045).fill(Self.crossBlue)
        DiagonalBand(left: 0.40, right: 0.68, thickness: 0.045).fill(accentColor)

        if PrintDetail.showsText(height: size.height) {
          TubeCode(code: code, size: size, color: .white, digitColor: accentColor)
            .offset(y: -size.height * 0.04)
        }
      }
    }
  }
}

// MARK: - Swix K universal

struct KlisterUniversalView: View {
  var stripeColor: Color?
  var code: String = ""

  static let swixRed = Color(red: 0.84, green: 0.15, blue: 0.17)
  private let silver = Color(red: 0.80, green: 0.82, blue: 0.85)

  var body: some View {
    KlisterTube(tubeColor: silver, crimpColor: silver, capColor: Color(white: 0.10)) { size in
      ZStack(alignment: .topLeading) {
        // Brushed aluminium.
        LinearGradient(
          colors: [.white.opacity(0.0), .white.opacity(0.45), .white.opacity(0.0)],
          startPoint: .top, endPoint: .bottom)
        DiagonalBand(left: 0.60, right: 0.28, thickness: 0.070).fill(Self.swixRed)

        if PrintDetail.showsText(height: size.height) {
          TubeCode(code: code, size: size, color: Self.swixRed)
            .offset(y: size.height * 0.06)
        }
      }
    }
  }
}

// MARK: - Rode klister

struct RodeKlisterView: View {
  var gradeColor: Color
  var accentColor: Color?
  var code: String = ""

  var body: some View {
    KlisterTube(
      tubeColor: gradeColor, crimpColor: Color(white: 0.96), capColor: Color(white: 0.96),
      aspect: 0.29, glossy: true
    ) { size in
      ZStack(alignment: .topLeading) {
        // White crimp band runs a little way down the tube.
        Rectangle().fill(Color(white: 0.96))
          .frame(width: size.width, height: size.height * 0.090)

        // Label band: "klister" and the colour name.
        Rectangle().fill(Color(white: 0.97))
          .frame(width: size.width, height: size.height * 0.120)
          .offset(y: size.height * 0.380)

        // The big Rode snowflake, printed straight onto the tube.
        Image(systemName: "snowflake")
          .font(.system(size: size.width * 0.78, weight: .bold))
          .foregroundStyle(gradeColor.isLight ? RodeCanGraphic.snowflakeBlue : .white.opacity(0.9))
          .position(x: size.width * 0.5, y: size.height * 0.655)

        if PrintDetail.showsText(height: size.height) {
          Text(verbatim: code)
            .font(.system(size: size.width * 0.26, weight: .bold).width(.condensed))
            .foregroundStyle(RodeCanGraphic.rodeRed)
            .position(x: size.width * 0.5, y: size.height * 0.440)
        }
      }
    }
  }
}

// MARK: - Preview

#Preview("Klister") {
  HStack(alignment: .bottom, spacing: 18) {
    KlisterCanView(bodyColor: Color(hex: "#D5452F")!, labelColor: Color(hex: "#EDCE86")!, code: "KX75")
    KlisterCanView(bodyColor: Color(hex: "#773C89")!, labelColor: Color(hex: "#8FBDE4")!, code: "KX45N")
    KlisterNeroView(accentColor: Color(hex: "#C27C76")!, code: "KN44")
    KlisterUniversalView(stripeColor: Color(hex: "#8FA6CF")!, code: "K21S")
    RodeKlisterView(gradeColor: Color(hex: "#C9342B")!, code: "K40")
  }
  .frame(height: 240)
  .padding()
}
