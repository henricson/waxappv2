import SwiftUI

/// Horizontally snapping snow-type picker. The selected chip sits in the
/// centre of the track so it reads as the current condition.
struct SnowTypeButtons: View {
  @Bindable var store: RecommendationStore

  @Namespace private var glassNamespace

  private var selected: SnowType { store.effectiveSnowType }

  /// One chip, whatever it stands for: a grip snow type, or a glide group.
  private struct Choice: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let snowType: SnowType
    let isSelected: Bool
  }

  private var choices: [Choice] {
    if store.activeDomain == .glide {
      let current = GlideSnow(selected)
      return GlideSnow.allCases.map {
        Choice(
          id: "glide.\($0.rawValue)", title: $0.title, detail: $0.detail, icon: $0.iconName,
          snowType: $0.representative, isSelected: $0 == current)
      }
    }
    return store.availableSnowTypes.map {
      Choice(
        id: "grip.\($0.rawValue)", title: $0.shortTitle, detail: $0.description, icon: $0.iconName,
        snowType: $0, isSelected: $0 == selected)
    }
  }

  private var selectedID: String? { choices.first(where: \.isSelected)?.id }

  /// The chip currently in the middle of the row.
  @State private var centredID: String?
  @State private var isScrolling = false


  var body: some View {
    // A picker wheel: the chip that comes to rest in the middle is the
    // selection. Tapping a chip scrolls it there; a change from outside
    // (the weather) does the same.
    GeometryReader { geo in
      ScrollView(.horizontal) {
        GlassEffectContainer(spacing: 0) {
          HStack(spacing: 10) {
            ForEach(choices) { choice in
              SnowTypeChip(title: choice.title, icon: choice.icon, isSelected: choice.isSelected)
                .glassEffectID(choice.id, in: glassNamespace)
                .contentShape(.capsule)
                .id(choice.id)
                .accessibilityLabel(choice.title)
                .accessibilityHint(choice.detail)
                .accessibilityIdentifier("snowType_\(choice.id)")
                .accessibilityAddTraits(choice.isSelected ? [.isSelected] : [])
                .onTapGesture {
                  withAnimation(.smooth(duration: 0.3)) { centredID = choice.id }
                  select(choice)
                }
            }
          }
          .scrollTargetLayout()
        }
      }
      .scrollIndicators(.hidden)
      // Room on each side for the first and last chip to reach the middle.
      .contentMargins(.horizontal, max(16, geo.size.width / 2 - 44), for: .scrollContent)
      .scrollTargetBehavior(.viewAligned(anchor: .center))
      .scrollPosition(id: $centredID, anchor: .center)
      .onScrollPhaseChange { _, phase in
        isScrolling = phase != .idle
        // Select only once the wheel has come to rest.
        if phase == .idle, let id = centredID, let choice = choices.first(where: { $0.id == id }) {
          select(choice)
        }
      }
      .onAppear { centredID = selectedID }
      .onChange(of: selectedID) { _, newValue in
        guard !isScrolling, centredID != newValue else { return }
        withAnimation(.smooth(duration: 0.35)) { centredID = newValue }
      }
      .sensoryFeedback(.selection, trigger: centredID)
    }
  }

  private func select(_ choice: Choice) {
    guard !choice.isSelected else { return }
    withAnimation(.smooth(duration: 0.3)) { store.effectiveSnowType = choice.snowType }
  }
}

private struct SnowTypeChip: View {
  let title: String
  let icon: String
  let isSelected: Bool

  var body: some View {
    Label(title, systemImage: icon)
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
