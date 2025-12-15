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
    
    var body : some View {
        HStack(spacing: 6) {
            if let icon {
                icon
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
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
