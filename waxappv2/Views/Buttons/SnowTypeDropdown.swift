//
//  SnowTypeSelector.swift
//  waxappv2
//
//  Created by Herman Henriksen on 17/12/2025.
//

import SwiftUI

struct SnowTypeDropdown: View {
    @Binding var selectedGroupBinding : SnowType
    
    var body: some View {
        Menu {
            Picker("Snow Type", selection: $selectedGroupBinding) {
                ForEach(SnowType.allCases, id: \.self) { group in
                    Label(group.title, systemImage: group.iconName).tag(group)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: $selectedGroupBinding.wrappedValue.iconName)
                    .imageScale(.medium)
                Text($selectedGroupBinding.wrappedValue.title)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Image(systemName: "chevron.up.chevron.down")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            }
            .font(.headline)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Snow Type")
            .accessibilityValue($selectedGroupBinding.wrappedValue.title)
            .accessibilityAddTraits(.isButton)
        }
        .controlSize(.regular)
        .buttonStyle(.bordered)
    }
}

#Preview {
    @Previewable @State var selectedGroupBinding : SnowType = .allCases.first!
    SnowTypeDropdown(selectedGroupBinding: $selectedGroupBinding)
}
