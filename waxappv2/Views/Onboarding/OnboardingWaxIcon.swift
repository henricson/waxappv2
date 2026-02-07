//
//  OnboardingWaxIcon.swift
//  waxappv2
//
//  Created by Herman Henriksen on 08/01/2026.
//
import SwiftUI

struct OnboardingWaxIcon: View {
  let wax: SwixWax

  var body: some View {
    Group {
      if wax.kind == .hardwax {
        WaxCanGraphic(
          bodyFill: AnyShapeStyle(Color(hex: wax.primaryColor) ?? .gray),
          bodyIllumination: LinearGradient(
            colors: [.white.opacity(0.35), .clear], startPoint: .topLeading,
            endPoint: .bottomTrailing),
          bodySpecular: LinearGradient(
            colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom),
          showBand: true,
          bandPrimaryColor: Color(hex: wax.primaryColor) ?? .white,
          bandSecondaryColor: (wax.secondaryColor.flatMap { Color(hex: $0) }) ?? .blue
        )
      } else {
        KlisterCanView(bodyColor: Color(hex: wax.primaryColor) ?? .white)
      }
    }
    .drawingGroup()  // smoother when many items animate
  }
}
