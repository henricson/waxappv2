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
                    if recommendedWax.kind == .hardwax {
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

                    }else if recommendedWax.kind == .klister {
                        KlisterCanView(bodyColor: headerPrimary)
                            .frame(height: 200)
                            .shadow(color: Color.black.opacity(0.1), radius: 5)
                            

                    }
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

#Preview("Wax") {
    let recommendedWax = swixWaxes.filter({$0.kind == .hardwax}).first!
    
    HeaderCanView(recommendedWax: recommendedWax)
   
    
}

#Preview("Klister") {
    let recommendedKlister = swixWaxes.filter({$0.kind == .klister}).first!
    
    HeaderCanView(recommendedWax: recommendedKlister)
   
    
}
