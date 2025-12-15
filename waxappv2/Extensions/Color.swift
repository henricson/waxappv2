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
}
