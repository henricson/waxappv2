import SwiftUI

/// Horizontally snapping snow-type picker. The selected chip sits in the
/// centre of the track so it reads as the current condition.
struct SnowTypeButtons: View {
  @Bindable var store: RecommendationStore

  @Namespace private var glassNamespace

  private var selected: SnowType { store.effectiveSnowType }

  var body: some View {
    // Selection is by tap only, and the chosen chip is always brought to
    // the middle. The old version snapped chips to the leading edge while
    // also trying to centre them, so the selected one landed off to the side.
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        // Container spacing below the HStack gap: glass shapes closer than
        // the container's spacing melt into each other.
        GlassEffectContainer(spacing: 0) {
          HStack(spacing: 10) {
            ForEach(store.availableSnowTypes) { type in
              SnowTypeChip(type: type, isSelected: type == selected)
                .id(type)
                .glassEffectID(type.id, in: glassNamespace)
                .accessibilityIdentifier("snowType_\(type.rawValue)")
                .accessibilityAddTraits(type == selected ? [.isSelected] : [])
                .onTapGesture {
                  guard type != selected else { return }
                  withAnimation(.smooth(duration: 0.3)) {
                    store.effectiveSnowType = type
                  }
                }
            }
          }
        }
      }
      .scrollIndicators(.hidden)
      .contentMargins(.horizontal, 16, for: .scrollContent)
      .sensoryFeedback(.selection, trigger: selected)
      .task {
        // One layout pass first, so the chips have their widths.
        await Task.yield()
        proxy.scrollTo(selected, anchor: .center)
      }
      .onChange(of: selected) { _, newValue in
        withAnimation(.smooth(duration: 0.35)) { proxy.scrollTo(newValue, anchor: .center) }
      }
      .onChange(of: store.availableSnowTypes) { _, _ in
        proxy.scrollTo(selected, anchor: .center)
      }
      // The row may first be laid out behind onboarding or a sheet at a
      // different width; re-centre whenever its width settles.
      .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.width } action: { _, _ in
        proxy.scrollTo(selected, anchor: .center)
      }
      .onAppear { proxy.scrollTo(selected, anchor: .center) }
    }
  }
}

private struct SnowTypeChip: View {
  let type: SnowType
  let isSelected: Bool

  var body: some View {
    Label(type.shortTitle, systemImage: type.iconName)
      .font(.subheadline.weight(.semibold))
      .lineLimit(1)
      .fixedSize(horizontal: true, vertical: false)
      .foregroundStyle(isSelected ? Color.white : Color.primary)
      .padding(.horizontal, 14)
      .padding(.vertical, 9)
      .glassEffect(
        isSelected
          ? .regular.tint(.accentColor).interactive()
          : .regular.interactive(),
        in: .capsule
      )
      .contentShape(.capsule)
      .accessibilityLabel(type.title)
      .accessibilityHint(type.description)
  }
}

#Preview {
  @Previewable @State var app = AppState()

  VStack {
    SnowTypeButtons(store: app.recommendation)
      .frame(height: 46)
    Text(app.recommendation.effectiveSnowType.title)
      .font(.caption)
  }
}
