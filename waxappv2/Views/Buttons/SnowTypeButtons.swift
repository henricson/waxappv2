//
//  SnowTypeButtons.swift
//  waxappv2
//
//  Created by Herman Henriksen on 19/10/2025.
//
import SwiftUI

struct SnowTypeButtons: View {
    @Binding var selected: SnowType

    @Environment(\.colorScheme) private var colorScheme

    private let interItemSpacing: CGFloat = 8

    @State private var scrollPosition: SnowType? = nil
    @State private var isProgrammaticScroll: Bool = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: interItemSpacing) {
                    ForEach(SnowType.allCases) { type in
                        SnowTypeChip(
                            type: type,
                            isSelected: type == selected,
                            colorScheme: colorScheme,
                            onTap: {
                                guard type != selected else { return }
                                isProgrammaticScroll = true
                                selected = type
                                withAnimation(.easeInOut) {
                                    scrollPosition = type
                                }
                                DispatchQueue.main.async {
                                    isProgrammaticScroll = false
                                }
                            }
                        )
                        .id(type)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, proxy.size.width / 2)
            .scrollTargetBehavior(.viewAligned)
            .defaultScrollAnchor(.center)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrollPosition, anchor: .center)
            
            .onAppear {
                isProgrammaticScroll = true
                scrollPosition = selected
                DispatchQueue.main.async {
                    isProgrammaticScroll = false
                }
            }
            .onChange(of: selected) { _, newValue in
                guard newValue != scrollPosition else { return }
                isProgrammaticScroll = true
                withAnimation(.easeInOut) {
                    scrollPosition = newValue
                }
                DispatchQueue.main.async {
                    isProgrammaticScroll = false
                }
            }
            .onChange(of: scrollPosition) { _, newValue in
                guard !isProgrammaticScroll else { return }
                guard let newValue, newValue != selected else { return }
                selected = newValue
            }
        }
    }
}

private struct SnowTypeChip: View {
    let type: SnowType
    let isSelected: Bool
    let colorScheme: ColorScheme
    let onTap: () -> Void

    var body: some View {
        let unselectedText: Color = (colorScheme == .dark) ? .white : .primary

        Button(action: onTap) {
            Label(type.title, systemImage: type.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : unselectedText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? Color.accentColor.opacity(0.6) : Color.primary.opacity(colorScheme == .dark ? 0.25 : 0.15),
                            lineWidth: isSelected ? 1.25 : 0.75
                        )
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.15 : 0.08), radius: 1, x: 0, y: 1)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selected: SnowType = .newFallen

    ZStack {
        SnowTypeButtons(selected: $selected)
            .frame(height: 60)

        // Center guide for debugging
        Rectangle()
            .frame(width: 1)
            .foregroundColor(.red)
    }
}
