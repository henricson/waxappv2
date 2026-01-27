//
//  HeaderCanView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 07/01/2026.
//


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

            VStack(spacing: 0) {
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
                    }else if recommendedWax.kind == .klister {
                        KlisterCanView(bodyColor: headerPrimary)
                            .shadow(color: Color.black.opacity(0.1), radius: 5)
                            .mask(
                                LinearGradient(gradient: Gradient(colors: [Color.black, Color.black.opacity(0)]), startPoint: .center, endPoint: .bottom)
                            )
                            

                    }
                    Spacer(minLength: 20)
                    VStack(spacing: 2) {
                        Text(LocalizedStringKey(recommendedWax.nameKey))
                            .font(.headline)
                            .foregroundStyle(headerPrimary.contrastingTextColor)
                            .onAppear {
                                print("🌍 Key: \(recommendedWax.nameKey)")
                                print("🌍 Preferred: \(Locale.preferredLanguages)")
                                print("🌍 Bundle localizations: \(Bundle.main.localizations)")
                            }
                        Text("\(recommendedWax.series) • \(recommendedWax.kindDisplay)")
                            .font(.caption)
                            .foregroundStyle(headerPrimary.contrastingTextColor.opacity(0.8))
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
