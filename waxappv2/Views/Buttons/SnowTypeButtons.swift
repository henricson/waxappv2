//
//  SnowTypeButtons.swift
//  waxappv2
//
//  Created by Herman Henriksen on 19/10/2025.
//
import SwiftUI

private struct SnowTypeButtonWidthKey: PreferenceKey {
    static var defaultValue: [SnowType: CGFloat] = [:]

    static func reduce(value: inout [SnowType: CGFloat], nextValue: () -> [SnowType: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct ViewportWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 1 { value = next }
    }
}

struct SnowTypeButtons: View {
    @Binding var selected: SnowType

    @Environment(\.colorScheme) private var colorScheme

    private let interItemSpacing: CGFloat = 8
    private let verticalPadding: CGFloat = 4
    private let fallbackButtonWidth: CGFloat = 140

    @State private var buttonWidths: [SnowType: CGFloat] = [:]
    @State private var viewportWidth: CGFloat = 0

    @State private var scrollPosition: SnowType? = nil

    var body: some View {
        // Compute asymmetric margins so the first/last item can land exactly on center.
        // Required margin for an edge item: (viewportWidth / 2) - (edgeItemWidth / 2)
        let firstType = SnowType.allCases.first
        let lastType = SnowType.allCases.last

        let firstWidth = firstType.flatMap { buttonWidths[$0] } ?? fallbackButtonWidth
        let lastWidth = lastType.flatMap { buttonWidths[$0] } ?? fallbackButtonWidth

        let leadingMargin = max(0, (viewportWidth / 2) - (firstWidth / 2))
        let trailingMargin = max(0, (viewportWidth / 2) - (lastWidth / 2))

        ScrollView(.horizontal) {
            HStack(spacing: interItemSpacing) {
                ForEach(SnowType.allCases) { type in
                    SnowTypeChip(
                        type: type,
                        isSelected: type == selected,
                        colorScheme: colorScheme,
                        onTap: { selected = type }
                    )
                    .id(type)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: SnowTypeButtonWidthKey.self, value: [type: geo.size.width])
                        }
                    )
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollPosition(id: $scrollPosition, anchor: UnitPoint.center)
        .scrollTargetBehavior(.viewAligned)
        .onAppear {
            scrollPosition = selected
        }
        .onChange(of: selected) { _, newValue in
            withAnimation(.easeInOut) {
                scrollPosition = newValue
            }
        }
        .onChange(of: scrollPosition) { _, newValue in
            guard let newValue, newValue != selected else { return }
            selected = newValue
        }
        .onPreferenceChange(ViewportWidthKey.self) { w in
            // Avoid transient/invalid widths during layout passes.
            guard w > 40, w < 4000 else { return }
            viewportWidth = w
        }
        .onPreferenceChange(SnowTypeButtonWidthKey.self) { widths in
            buttonWidths = widths
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

    SnowTypeButtons(selected: $selected)
}
