//
//  SnowTypeButtons.swift
//  waxappv2
//
//  Created by Herman Henriksen on 19/10/2025.
//
import SwiftUI

struct SnowTypeButtons: View {
    @Binding var selected: SnowType

    // Tune these if your buttons are wider/narrower on average
    private let estimatedButtonWidth: CGFloat = 140
    private let interItemSpacing: CGFloat = 8
    private let verticalPadding: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let sidePadding = max(0, (geo.size.width - estimatedButtonWidth) / 2)

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: interItemSpacing) {
                        // Leading spacer to allow centering the first items (safe content margin)
                        Color.clear
                            .frame(width: sidePadding, height: 1)
                            .accessibilityHidden(true)

                        ForEach(SnowType.allCases) { group in
                            let isSel = isSelected(group)

                            Button {
                                withAnimation(.easeInOut) {
                                    selected = group
                                    proxy.scrollTo(group, anchor: .center)
                                }
                            } label: {
                                Label(group.title, systemImage: icon(for: group))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(isSel ? .blue : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isSel ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.15), lineWidth: isSel ? 1.25 : 0.75)
                                    )
                                    .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .id(group) // make scroll targetable
                        }

                        // Trailing spacer to allow centering the last items (safe content margin)
                        Color.clear
                            .frame(width: sidePadding, height: 1)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, verticalPadding)
                }
                .onAppear {
                    // Initial centering of the selected value
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(selected, anchor: .center)
                        }
                    }
                }
                .onChange(of: selected) { _, newValue in
                    withAnimation(.easeInOut) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
        // Give the GeometryReader a reasonable intrinsic height
        .frame(height: 40)
    }

    // MARK: - Helpers

    private func isSelected(_ group: SnowType) -> Bool {
        group == selected
    }

    private func icon(for group: SnowType) -> String {
        switch group {
        case .newFallen: return "snow"
        case .moistNewFallen: return "cloud.snow"
        case .fineGrained: return "hexagon"
        case .moistFineGrained: return "hexagon.lefthalf.filled"
        case .oldGrained: return "circle.grid.2x1"
        case .transformedMoistFine: return "rhombus"
        case .frozenCorn: return "snowflake"
        case .wetCorn: return "drop"
        case .veryWetCorn: return "drop.fill"
        }
    }
}

#Preview {
    @Previewable @State var selected: SnowType = .newFallen
    VStack(alignment: .leading, spacing: 16) {
        SnowTypeButtons(selected: $selected)
    }
    .padding()
}

