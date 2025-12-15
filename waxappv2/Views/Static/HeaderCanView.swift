//
//  HeaderCanView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 28/11/2025.
//

import SwiftUI

struct HeaderCanView : View {
    let recommendedWax: SwixWax

    
    private var headerPrimary: Color {
        if let c = Color(hex: recommendedWax.primaryColor) {
            return c
        }
        return .blue
    }

    private var headerSecondary: Color {
        if let c = Color(hex: recommendedWax.secondaryColor ?? "#333") {
            return c
        }
        return .blue
    }

    private var headerBandColor: Color {
        let kind = recommendedWax.kind
        switch kind {
        case .hardwax: return .blue
        case .klister: return .orange
        case .base: return .gray
        }
    }
    
        var body : some View {

                VStack {
                    WaxCanGraphic(
                        // Use defaults for topFill and middleFill to keep lid white/metallic
                        bodyFill: AnyShapeStyle(headerPrimary),
                        bodyIllumination: LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        bodySpecular: LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom),
                        showBand: true,
                        bandPrimaryColor: headerBandColor,
                        bandSecondaryColor: headerSecondary
                    )
                    .frame(height: 200)
                    Spacer(minLength: 20)
                    VStack(spacing: 2) {
                        Text("\(recommendedWax.code) \(recommendedWax.name)")
                            .font(.headline)
                        Text("\(recommendedWax.series) • \(recommendedWax.kindDisplay)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            
 
    }
}

#Preview {
    let recommendedWax = swixWaxes[2]
    
    HeaderCanView(recommendedWax: recommendedWax)
   
    
}
