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

  var body: some View {
    // Selection is by tap only, and the chosen chip is always brought to
    // the middle.
    GeometryReader { geo in
    ScrollViewReader { proxy in
      ScrollView(.horizontal) {
        GlassEffectContainer(spacing: 0) {
          HStack(spacing: 10) {
            ForEach(choices) { choice in
              SnowTypeChip(title: choice.title, icon: choice.icon, isSelected: choice.isSelected)
                .id(choice.id)
                .glassEffectID(choice.id, in: glassNamespace)
                .accessibilityLabel(choice.title)
                .accessibilityHint(choice.detail)
                .accessibilityIdentifier("snowType_\(choice.id)")
                .accessibilityAddTraits(choice.isSelected ? [.isSelected] : [])
                .onTapGesture {
                  guard !choice.isSelected else { return }
                  withAnimation(.smooth(duration: 0.3)) {
                    store.effectiveSnowType = choice.snowType
                  }
                }
            }
          }
        }
      }
      .scrollIndicators(.hidden)
      // Room on both sides for the first and last chip to reach the middle,
      // like a picker wheel; selection is always centred.
      .contentMargins(.horizontal, max(16, geo.size.width / 2 - 56), for: .scrollContent)
      .onScrollPhaseChange { _, phase in
        // After a manual scroll, settle back on the selected chip.
        guard phase == .idle, let selectedID else { return }
        Task {
          try? await Task.sleep(for: .seconds(1.2))
          withAnimation(.smooth(duration: 0.35)) { proxy.scrollTo(selectedID, anchor: .center) }
        }
      }
      .sensoryFeedback(.selection, trigger: selectedID)
      .task {
        await Task.yield()
        if let selectedID { proxy.scrollTo(selectedID, anchor: .center) }
      }
      .onChange(of: selectedID) { _, newValue in
        guard let newValue else { return }
        withAnimation(.smooth(duration: 0.35)) { proxy.scrollTo(newValue, anchor: .center) }
      }
      // The row may first be laid out behind onboarding or a sheet at a
      // different width; re-centre whenever its width settles.
      .onScrollGeometryChange(for: CGFloat.self) { $0.containerSize.width } action: { _, _ in
        if let selectedID { proxy.scrollTo(selectedID, anchor: .center) }
      }
      .onAppear { if let selectedID { proxy.scrollTo(selectedID, anchor: .center) } }
    }
    }
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
