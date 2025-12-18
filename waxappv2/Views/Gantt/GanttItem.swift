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
    
    @State private var contentWidth: CGFloat = 0
    
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
    
    // Detect if the primary background color is dark to add a thin white outline
    private var isDarkBackground: Bool {
        #if canImport(UIKit)
        let uiColor = UIColor(primaryColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            return luminance < 0.2 // treat very dark colors as dark
        } else {
            return false
        }
        #elseif canImport(AppKit)
        let nsColor = NSColor(primaryColor)
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let r = converted.redComponent
        let g = converted.greenComponent
        let b = converted.blueComponent
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.2
        #else
        return false
        #endif
    }
    
    var body : some View {
        GeometryReader { proxy in
            // Get frame in the named coordinate space "ganttScroll"
            // If not found, it falls back to global
            let frame = proxy.frame(in: .named("ganttScroll"))
            let minX = frame.minX
            let width = proxy.size.width
            
            // Calculate sticky padding:
            // We want the content to stick to the left edge (minX), but not overflow the right edge.
            // The content (Icon + Text) has width `contentWidth`.
            // The available space for sliding is `width - 16 - contentWidth`.
            // If `width` is small, this might be negative (no sliding).
            let maxStickyPadding = max(0, width - 16 - contentWidth)
            
            // If minX is negative (scrolled left), we add padding to push content right.
            // But we clamp it to maxStickyPadding so it flows out with the item end.
            let stickyPadding = max(0, min(-minX, maxStickyPadding))

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
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .background(
                GeometryReader { contentProxy in
                    Color.clear
                        .onAppear { contentWidth = contentProxy.size.width }
                        .onChange(of: contentProxy.size.width) { _, newWidth in
                            contentWidth = newWidth
                        }
                }
            )
            .padding(.leading, 8 + stickyPadding)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(primaryColor)
            .cornerRadius(50)
            .overlay(
                RoundedRectangle(cornerRadius: 50)
                    .stroke(isDarkBackground ? Color.white.opacity(0.9) : Color.clear, lineWidth: 0.75)
            )
            .shadow(color: isDarkBackground ? Color.white.opacity(0.25) : Color.clear, radius: 1, x: 0, y: 0)
        }
        .frame(height: 30) // approximate height to fit icon and padding
    }
}

#Preview {
    ScrollView {
        VStack {
            ForEach(swixWaxes) { wax in
                let waxIcon : any View = wax.kind == .hardwax ? WaxCanGraphic(
                    bodyFill: AnyShapeStyle(Color(hex: wax.primaryColor) ?? .gray),
                    bodyIllumination: LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    bodySpecular: LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom),
                    showBand: true,
                    bandPrimaryColor: Color(hex: wax.primaryColor) ?? .white,
                    bandSecondaryColor: (wax.secondaryColor.flatMap { Color(hex: $0) }) ?? .blue
                    
                ): KlisterCanView(bodyColor: Color(hex: wax.primaryColor) ?? .white)
                    
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
