//
//  LocationSourceIndicator.swift
//  waxappv2
//
//  Created by Herman Henriksen on 13/01/2026.
//

import SwiftUI

/// A pill-shaped indicator showing whether data is from GPS location or manually selected location
struct LocationSourceIndicator: View {
    let isManualOverride: Bool
    let isUsingWeatherData: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var shouldShow: Bool {
        isUsingWeatherData
    }
    
    private var icon: String {
        isManualOverride ? "map" : "location.fill"
    }
    
    private var text: String {
        isManualOverride ? NSLocalizedString("At selected location", comment: "Label indicating that posiiton is selected location") : NSLocalizedString("At your location", comment: "Label indicating that position is current location")
    }
    
    var body: some View {
        if shouldShow {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(text)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1),
                        lineWidth: 0.5
                    )
            )
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                )
            )
        }
    }
}

#Preview("GPS Location") {
    VStack(spacing: 20) {
        LocationSourceIndicator(
            isManualOverride: false,
            isUsingWeatherData: true
        )
        
        LocationSourceIndicator(
            isManualOverride: false,
            isUsingWeatherData: false
        )
    }
    .padding()
}

#Preview("Manual Location") {
    VStack(spacing: 20) {
        LocationSourceIndicator(
            isManualOverride: true,
            isUsingWeatherData: true
        )
        
        LocationSourceIndicator(
            isManualOverride: true,
            isUsingWeatherData: false
        )
    }
    .padding()
}
