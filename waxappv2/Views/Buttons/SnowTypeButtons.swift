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
        let widest = buttonWidths.values.max() ?? fallbackButtonWidth
        let sideMargin = max(0, (viewportWidth - widest) / 2)

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
            .padding(.vertical, verticalPadding)
            // Correct placement: targets are the HStack's children.
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        // Measure the scroll view's own laid out width (works in MainView's nested stacks/scroll views).
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ViewportWidthKey.self, value: geo.size.width)
            }
        )
        .contentMargins(.horizontal, sideMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
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
            guard w > 40, w < 4000 else { return }
            viewportWidth = w
        }
        .onPreferenceChange(SnowTypeButtonWidthKey.self) { widths in
            buttonWidths = widths
        }
        .frame(height: 40)
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

    VStack(spacing: 24) {
        SnowTypeButtons(selected: $selected)
        SnowTypeButtons(selected: $selected)
            .padding(.horizontal, 32)
    }
    .padding()
}
