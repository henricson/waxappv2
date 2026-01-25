//
//  FloatingPurchaseButton.swift
//  waxappv2
//
//  Created by Herman Henriksen on 25/01/2026.
//
import SwiftUI

struct FloatingPurchaseButton: View {
    var remainingDays: Int
    var onPurchase: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("\(remainingDays) left of trial")
                .foregroundStyle(.secondary)
            Button {
                onPurchase()
            } label: {
                Text("Buy now")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.regularMaterial)
        )
        .overlay(
            Capsule()
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    FloatingPurchaseButton(remainingDays: 5) {
        print("Purchase button tapped!")
    }
}
