import SwiftUI

struct SnowTypeButtons: View {
    @Binding var selected: SnowType
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let interItemSpacing: CGFloat = 8
    
    @State private var scrolledID: SnowType?
    @State private var chipWidths: [SnowType: CGFloat] = [:]
    
    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            
            ScrollView(.horizontal) {
                HStack(spacing: interItemSpacing) {
                    ForEach(SnowType.allCases) { type in
                        SnowTypeChip(
                            type: type,
                            isSelected: type == selected,
                            colorScheme: colorScheme
                        )
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        chipWidths[type] = geo.size.width
                                    }
                            }
                        )
                        .id(type)
                        .onTapGesture {
                            guard type != selected else { return }
                            selected = type
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .safeAreaPadding(.horizontal, containerWidth / 2)
            .scrollTargetBehavior(CenterSnappingBehavior(
                chipWidths: chipWidths,
                interItemSpacing: interItemSpacing,
                containerWidth: containerWidth
            ))
            .scrollPosition(id: $scrolledID, anchor: .center)
            .scrollIndicators(.hidden)
            .onAppear {
                scrolledID = selected
            }
            .onChange(of: selected) { _, newValue in
                withAnimation(.easeOut(duration: 0.25)) {
                    scrolledID = newValue
                }
            }
            .onChange(of: scrolledID) { _, newValue in
                guard let newValue, newValue != selected else { return }
                selected = newValue
            }        .frame(height: .leastNormalMagnitude)

        }
        .frame(height: .leastNormalMagnitude)
            
    }
}

private struct CenterSnappingBehavior: ScrollTargetBehavior {
    let chipWidths: [SnowType: CGFloat]
    let interItemSpacing: CGFloat
    let containerWidth: CGFloat
    
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard chipWidths.count == SnowType.allCases.count else { return }
        
        // With safeAreaPadding, content starts at 0 and the padding is outside
        // target.rect.origin.x is the scroll offset
        // At offset 0, the first chip's leading edge is at the container's center
        
        // Current target center in content space
        let targetCenter = target.rect.midX
        
        // Build chip centers
        var chipCenters: [(SnowType, CGFloat)] = []
        var x: CGFloat = 0
        for type in SnowType.allCases {
            let width = chipWidths[type] ?? 0
            chipCenters.append((type, x + width / 2))
            x += width + interItemSpacing
        }
        
        // Find nearest
        var nearest = SnowType.allCases.first!
        var nearestCenter: CGFloat = 0
        var nearestDist = CGFloat.infinity
        
        for (type, center) in chipCenters {
            let dist = abs(targetCenter - center)
            if dist < nearestDist {
                nearestDist = dist
                nearest = type
                nearestCenter = center
            }
        }
        
        // Adjust target so nearest chip's center is at rect's center
        let halfWidth = target.rect.width / 2
        target.rect.origin.x = nearestCenter - halfWidth
    }
}

private struct SnowTypeChip: View {
    let type: SnowType
    let isSelected: Bool
    let colorScheme: ColorScheme
    
    var body: some View {
        let unselectedText: Color = (colorScheme == .dark) ? .white : .primary
        
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
}

#Preview {
    @Previewable @State var selected: SnowType = .fineGrained
    
    ZStack {
        SnowTypeButtons(selected: $selected)
        
        Rectangle()
            .frame(width: 1)
            .foregroundColor(.red)
    }
}
