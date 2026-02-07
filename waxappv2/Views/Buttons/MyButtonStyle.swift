//
//
//  MyButtonStyle.swift
//  waxappv2
//
//  Created by Herman Henriksen on 26/01/2026.
//

import SwiftUI

struct CircleBackgroundButtonStyle: ButtonStyle {
  let backgroundColor: Color

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        Circle()
          .fill(backgroundColor)
      )
  }
}

extension ButtonStyle where Self == CircleBackgroundButtonStyle {
  static func circleBackground(_ color: Color) -> CircleBackgroundButtonStyle {
    CircleBackgroundButtonStyle(backgroundColor: color)
  }
}
