//
//  FloatingPurchaseButton.swift
//  waxappv2
//

import SwiftUI

struct FloatingPurchaseButton: View {
  var subtitle: String
  var actionTitle: String
  var onPurchase: () -> Void

  var body: some View {
    GlassEffectContainer(spacing: 14) {
      HStack(spacing: 12) {
        Image(systemName: "sparkles")
          .font(.footnote)
          .foregroundStyle(.tint)

        Text(subtitle)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .minimumScaleFactor(0.85)

        Spacer(minLength: 4)

        Button(action: onPurchase) {
          Text(actionTitle)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
      }
      .padding(.leading, 16)
      .padding(.trailing, 8)
      .padding(.vertical, 8)
      .glassEffect(.regular, in: .capsule)
    }
  }
}

#Preview {
  FloatingPurchaseButton(
    subtitle: "Start your 14-day free trial",
    actionTitle: "Start trial"
  ) {}
    .padding()
    .background(.blue.opacity(0.3))
}
