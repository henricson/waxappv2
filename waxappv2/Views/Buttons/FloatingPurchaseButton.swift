//
//  FloatingPurchaseButton.swift
//  waxappv2
//
//  Created by Herman Henriksen on 25/01/2026.
//
import SwiftUI

struct FloatingPurchaseButton: View {
    var subtitle: String
    var actionTitle: String
    var onPurchase: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text(subtitle)
                .foregroundStyle(.secondary)
            Button {
                onPurchase()
            } label: {
                Text(actionTitle)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.regularMaterial)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    FloatingPurchaseButton(subtitle: "Start your 14-day free trial", actionTitle: "Start trial") {
        print("Purchase button tapped!")
    }
}
