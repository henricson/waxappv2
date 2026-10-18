import SwiftUI

/// Horizontally snapping snow-type picker. The selected chip sits in the
/// centre of the track so it reads as the current condition.
struct SnowTypeButtons: View {
  @Bindable var store: RecommendationStore

  @State private var scrolledID: SnowType?
  @Namespace private var glassNamespace

  private var selected: SnowType { store.effectiveSnowType }

  var body: some View {
    ScrollView(.horizontal) {
      // Container spacing below the HStack gap: glass shapes closer than the
      // container's spacing melt into each other, which bridged every chip
      // to its neighbour.
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
                  scrolledID = type
                }
              }
          }
        }
        .scrollTargetLayout()
      }
    }
    .scrollIndicators(.hidden)
    .scrollTargetBehavior(.viewAligned)
    .scrollPosition(id: $scrolledID, anchor: .center)
    .contentMargins(.horizontal, 24, for: .scrollContent)
    .sensoryFeedback(.selection, trigger: selected)
    .onAppear { scrolledID = selected }
    .onChange(of: selected) { _, newValue in
      guard scrolledID != newValue else { return }
      withAnimation(.smooth(duration: 0.3)) { scrolledID = newValue }
    }
    .onChange(of: scrolledID) { _, newValue in
      guard let newValue, newValue != selected else { return }
      store.effectiveSnowType = newValue
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
