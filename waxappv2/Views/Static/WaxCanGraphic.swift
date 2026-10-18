//
//  WaxCanGraphic.swift
//  waxappv2
//
//  Hard-wax tins, drawn from the manufacturers' packshots.
//
//  Swix V-line:  grade-colour tin, white snap lid, and the
//                signature band rising diagonally across the body, with the
//                product code set along it and a skier pictogram.
//  Swix VP-line: black tin and black lid, a large grey "VP" over the grade
//                digits, and a grade-colour mountain ridge round the foot.
//  Rode:         white lid, a white printed panel framed top and bottom by
//                the grade colour, and the big blue Rode snowflake.
//
//  A 45 g tin is about 47 mm across and 70 mm tall with its lid on, so all
//  three are drawn at that 2:3 proportion. Brand wordmarks are left off on
//  purpose — a faux logo reads as a knock-off — but product codes are
//  printed once the tin is large enough to read them.
//

import SwiftUI

// MARK: - Geometry

nonisolated enum TinGeometry {
  static let aspect: CGFloat = 0.67

  /// Half-height of every rim ellipse: how far we look down onto the tin.
  static let rim: CGFloat = 0.026

  // Lid: centre line of the top ellipse, and the skirt's lower rim.
  static let lidTop: CGFloat = 0.040
  static let lidBottom: CGFloat = 0.180
  static let lidLeft: CGFloat = 0.060
  static let lidRight: CGFloat = 0.940

  // The body is a touch narrower than the lid, which snaps over it.
  static let bodyTop: CGFloat = 0.170
  static let bodyBottom: CGFloat = 0.960
  static let bodyLeft: CGFloat = 0.095
  static let bodyRight: CGFloat = 0.905

  /// The printable side of the body, for laying out bands and print.
  static func bodyRect(in size: CGSize) -> CGRect {
    CGRect(
      x: bodyLeft * size.width, y: bodyTop * size.height,
      width: (bodyRight - bodyLeft) * size.width,
      height: (bodyBottom - bodyTop) * size.height)
  }

  static let lidSide = CylinderSide(left: lidLeft, right: lidRight, top: lidTop, bottom: lidBottom, rim: rim)
  static let lidFace = CylinderTop(left: lidLeft, right: lidRight, top: lidTop, rim: rim)
}

/// The can body: a cylinder whose foot curves away from the eye on the same
/// ellipse as the lid rim.
nonisolated struct TinBody: Shape {
  func path(in rect: CGRect) -> Path {
    CylinderSide(
      left: TinGeometry.bodyLeft, right: TinGeometry.bodyRight,
      top: TinGeometry.bodyTop, bottom: TinGeometry.bodyBottom, rim: TinGeometry.rim
    ).path(in: rect)
  }
}

// MARK: - Shared tin

/// Lid, body silhouette and lighting shared by every tin; `print` is the
/// label artwork, laid out in the body's own coordinate space.
private struct Tin<Print: View>: View {
  var bodyColor: Color
  var lidColor: Color
  @ViewBuilder var print: (CGRect, CGFloat) -> Print

  var body: some View {
    ContainerCanvas(aspect: TinGeometry.aspect, baseline: 0.945) { size in
      let line = size.height * 0.004
      let body = TinGeometry.bodyRect(in: size)
      let isLightLid = lidColor.isLight

      ZStack(alignment: .topLeading) {
        TinBody().fill(bodyColor)

        print(body, size.height)
          .frame(width: size.width, height: size.height, alignment: .topLeading)
          .mask(TinBody())

        // Shading over the print, so the label curves with the tin.
        TinBody().cylinderLit()

        TinBody().stroke(.black.opacity(0.20), lineWidth: line)

        // Lid skirt, then the face you look down on.
        TinGeometry.lidSide.fill(lidColor)
        TinGeometry.lidSide.lidLit()
        TinGeometry.lidSide.stroke(.black.opacity(0.18), lineWidth: line)

        TinGeometry.lidFace
          .fill(
            LinearGradient(
              colors: isLightLid
                ? [.white, Color(white: 0.93)]
                : [lidColor.opacity(0.75), lidColor],
              startPoint: .topLeading, endPoint: .bottomTrailing))
        TinGeometry.lidFace
          .stroke(isLightLid ? Color.black.opacity(0.10) : Color.white.opacity(0.18), lineWidth: line)
      }
      .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
  }
}

// MARK: - Swix V tin

struct WaxCanGraphic: View {
  var bodyColor: Color
  var bandColor: Color?
  var code: String = ""

  // The band climbs from low on the left to high on the right.
  private let bandLeft: CGFloat = 0.74
  private let bandRight: CGFloat = 0.30
  private let bandThickness: CGFloat = 0.20

  var body: some View {
    Tin(bodyColor: bodyColor, lidColor: .white) { body, height in
      let band = bandColor ?? bodyColor.opacity(0.6)

      ZStack(alignment: .topLeading) {
        DiagonalBand(left: bandLeft, right: bandRight, thickness: bandThickness)
          .fill(band)

        if PrintDetail.showsText(height: height) {
          let angle = DiagonalBand.angle(left: bandLeft, right: bandRight, in: body.size)
          let parts = PrintedCode.split(code)
          PrintedCode(
            letters: parts.letters, digits: parts.digits,
            size: body.height * 0.16,
            letterColor: band.isLight ? .black.opacity(0.8) : .white,
            italic: true
          )
          .rotationEffect(angle)
          .position(x: body.width * 0.50, y: body.height * ((bandLeft + bandRight) / 2 + bandThickness / 2))

          Image(systemName: "figure.skiing.crosscountry")
            .font(.system(size: body.height * 0.20, weight: .semibold))
            .foregroundStyle(bodyColor.isLight ? Color.black.opacity(0.55) : .white)
            .position(x: body.width * 0.72, y: body.height * 0.80)
        }
      }
      .frame(width: body.width, height: body.height, alignment: .topLeading)
      .offset(x: body.minX, y: body.minY)
    }
  }
}

// MARK: - Swix VP tin

struct WaxCanVPGraphic: View {
  var gradeColor: Color
  var code: String = ""

  private let black = Color(white: 0.10)

  var body: some View {
    Tin(bodyColor: black, lidColor: Color(white: 0.13)) { body, height in
      ZStack(alignment: .topLeading) {
        SwixRidge(top: 0.70, depth: 0.12, isBackdrop: true)
          .fill(Color(white: 0.30))
        SwixRidge(top: 0.76, depth: 0.12)
          .fill(gradeColor)

        if PrintDetail.showsText(height: height) {
          let parts = PrintedCode.split(code)
          PrintedCode(
            letters: parts.letters, digits: parts.digits,
            size: body.width * 0.40,
            letterColor: Color(white: 0.55), digitColor: gradeColor
          )
          .position(x: body.width * 0.50, y: body.height * 0.40)
        }
      }
      .frame(width: body.width, height: body.height, alignment: .topLeading)
      .offset(x: body.minX, y: body.minY)
    }
  }
}

// MARK: - Rode tin

struct RodeCanGraphic: View {
  var gradeColor: Color
  var code: String = ""

  static let snowflakeBlue = Color(red: 0.10, green: 0.36, blue: 0.72)
  static let rodeRed = Color(red: 0.84, green: 0.13, blue: 0.16)

  var body: some View {
    Tin(bodyColor: Color(white: 0.97), lidColor: Color(white: 0.97)) { body, height in
      ZStack(alignment: .topLeading) {
        // The grade colour is a deep band round the foot.
        Rectangle().fill(gradeColor)
          .frame(width: body.width, height: body.height * 0.27)
          .offset(y: body.height * 0.73)

        Image(systemName: "snowflake")
          .font(.system(size: body.height * 0.44, weight: .bold))
          .foregroundStyle(Self.snowflakeBlue)
          .position(x: body.width * 0.50, y: body.height * 0.42)

        if PrintDetail.showsFineDetail(height: height) {
          // The red wordmark plate across the snowflake, without the word.
          Capsule()
            .fill(Self.rodeRed)
            .overlay(Capsule().stroke(.white, lineWidth: body.height * 0.012))
            .frame(width: body.width * 0.70, height: body.height * 0.13)
            .position(x: body.width * 0.50, y: body.height * 0.42)
        }

        if PrintDetail.showsText(height: height) {
          Text(verbatim: code)
            .font(.system(size: body.height * 0.085, weight: .bold).width(.condensed))
            .foregroundStyle(gradeColor.isLight ? Color.black.opacity(0.75) : .white)
            .position(x: body.width * 0.50, y: body.height * 0.85)
        }
      }
      .frame(width: body.width, height: body.height, alignment: .topLeading)
      .offset(x: body.minX, y: body.minY)
    }
  }
}

// MARK: - Previews

#Preview("Swix tins") {
  HStack(alignment: .bottom, spacing: 16) {
    WaxCanGraphic(bodyColor: Color(hex: "#3D78E5")!, bandColor: Color(hex: "#A9C8F6")!, code: "V40")
    WaxCanGraphic(bodyColor: Color(hex: "#5A8F3C")!, bandColor: Color(hex: "#B7D49B")!, code: "V20")
    WaxCanVPGraphic(gradeColor: Color(hex: "#9B8FDD")!, code: "VP45")
  }
  .frame(height: 200)
  .padding()
}

#Preview("Rode tins") {
  HStack(alignment: .bottom, spacing: 16) {
    RodeCanGraphic(gradeColor: Color(hex: "#7B4C9E")!, code: "P40")
    RodeCanGraphic(gradeColor: Color(hex: "#C9342B")!, code: "P50")
    RodeCanGraphic(gradeColor: Color(hex: "#7B4C9E")!).frame(width: 20, height: 30)
  }
  .frame(height: 200)
  .padding()
}
