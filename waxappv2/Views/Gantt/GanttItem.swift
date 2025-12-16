//
//  GanttItem.swift
//  waxappv2
//
//  Created by Herman Henriksen on 01/12/2025.
//

import SwiftUI

struct GanttItem: View {
    var primaryColor: Color
    var secondaryColor: Color? // made optional
    var icon: AnyView? = nil
    var title : String
    
    init(primaryColor: Color, icon: AnyView? = nil, title: String, secondaryColor: Color? = nil) {
        self.primaryColor = primaryColor
        self.icon = icon
        self.title = title
        self.secondaryColor = secondaryColor // keep optional
    }
    
    // Choose text color based on background contrast
    private var adaptiveTextColor: Color {
        // Convert the primary color to sRGB components if possible
        #if canImport(UIKit)
        let uiColor = UIColor(primaryColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            // Perceived luminance (WCAG-ish): 0 (black) - 1 (white)
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            // If background is bright, prefer black text; otherwise white
            return luminance > 0.6 ? .black : .white
        } else {
            return .white
        }
        #elseif canImport(AppKit)
        let nsColor = NSColor(primaryColor)
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let r = converted.redComponent
        let g = converted.greenComponent
        let b = converted.blueComponent
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.6 ? .black : .white
        #else
        return .white
        #endif
    }
    
    var body : some View {
        HStack(spacing: 6) {
            if let icon {
                icon
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(adaptiveTextColor)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(primaryColor)
        .cornerRadius(50)




    }
}

#Preview {
    ScrollView {
        VStack {
            ForEach(swixWaxes) { wax in
                let waxIcon = WaxCanGraphic(
                    bodyFill: AnyShapeStyle(Color(hex: wax.primaryColor) ?? .gray),
                    bodyIllumination: LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    bodySpecular: LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom),
                    showBand: true,
                    bandPrimaryColor: Color(hex: wax.primaryColor) ?? .white,
                    bandSecondaryColor: (wax.secondaryColor.flatMap { Color(hex: $0) }) ?? .blue
                )
                GanttItem(
                    primaryColor: Color(hex: wax.primaryColor) ?? .blue,
                    icon: AnyView(waxIcon),
                    title: wax.name,
                    secondaryColor: (wax.secondaryColor != nil) ? Color(hex: wax.secondaryColor!) : nil
                )
                .frame(maxWidth: .infinity) // make as wide as parent
            }
        }
    }
}

