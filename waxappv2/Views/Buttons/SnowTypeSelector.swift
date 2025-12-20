//
//  SnowTypeSelector.swift
//  waxappv2
//
//  Created by Herman Henriksen on 17/12/2025.
//

import SwiftUI

struct SnowTypeSelector: View {
    @Binding var selectedGroupBinding : SnowType
    
    var body: some View {
        Menu {
            Picker("Snow Type", selection: $selectedGroupBinding) {
                ForEach(SnowType.allCases, id: \.self) { group in
                    Label(group.title, systemImage: group.iconName).tag(group)
                }
            }
            // Optional: This style often looks better in menus
            // .pickerStyle(.inline)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: $selectedGroupBinding.wrappedValue.iconName)
                Text($selectedGroupBinding.wrappedValue.title)
                    .fontWeight(.medium)
                
                // Chevron indicates this is a dropdown/menu
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(.regularMaterial, in: Capsule())
            // Add a border or stroke to make it pop slightly more if needed
            .overlay(
                Capsule()
                    .strokeBorder(.separator, lineWidth: 0.5)
            )
        }
        // Ensure the button style doesn't override our custom label colors
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selectedGroupBinding : SnowType = .allCases.first!
    SnowTypeSelector(selectedGroupBinding: $selectedGroupBinding)
}
