//
//  Color.swift
//  waxappv2
//
//  Created by Herman Henriksen on 28/11/2025.
//

import SwiftUI

extension Color {
    init?(hex: String) {
        let raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard let int = UInt64(raw, radix: 16) else { return nil }
        let r, g, b, a: Double
        switch raw.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255
            g = Double((int >> 16) & 0xFF) / 255
            b = Double((int >> 8) & 0xFF) / 255
            a = Double(int & 0xFF) / 255
        default:
            return nil
        }
        self = Color(red: r, green: g, blue: b, opacity: a)
    }

    var isLight: Bool {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            return luminance > 0.5
        }
        return true
        #elseif canImport(AppKit)
        let nsColor = NSColor(self)
        let converted = nsColor.usingColorSpace(.sRGB) ?? nsColor
        let r = converted.redComponent
        let g = converted.greenComponent
        let b = converted.blueComponent
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.5
        #else
        return true
        #endif
    }

    var contrastingTextColor: Color {
        return isLight ? .black : .white
    }
}
