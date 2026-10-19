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

  /// Scroll position of the row; its view id is the chip in the middle.
  @State private var position = ScrollPosition(idType: String.self)
  private var centredID: String? { position.viewID(type: String.self) }
  @State private var isScrolling = false
  @State private var pendingSelection: Task<Void, Never>?


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
                  centre(on: choice.id, animated: true)
                  select(choice)
                }
            }
          }
          .scrollTargetLayout()
        }
      }
      .scrollIndicators(.hidden)
      // Centre-anchored snapping lines a chip's centre up with the edge of
      // the content margin, so the margin must be exactly half the width.
      // That also lets the first and last chip reach the middle.
      .contentMargins(.horizontal, geo.size.width / 2, for: .scrollContent)
      .scrollTargetBehavior(.viewAligned(anchor: .center))
      .scrollPosition($position, anchor: .center)
      .onScrollPhaseChange { _, phase in
        isScrolling = phase != .idle
        guard phase == .idle, let id = centredID else { return }
        // The system's snap lands a chip near the middle; finish the last
        // few points so it sits exactly in the centre, as a tap does.
        centre(on: id, animated: true)
        selectCentred()
      }
      // Like a picker wheel, the selection follows the chip passing through
      // the middle, so it never waits for the scroll to coast to a stop.
      .onChange(of: centredID) { _, _ in
        guard isScrolling else { return }
        pendingSelection?.cancel()
        pendingSelection = Task {
          try? await Task.sleep(for: .milliseconds(90))
          guard !Task.isCancelled else { return }
          selectCentred()
        }
      }
      .onAppear { if let selectedID { centre(on: selectedID, animated: false) } }
      .onChange(of: selectedID) { _, newValue in
        guard !isScrolling, let newValue, centredID != newValue else { return }
        centre(on: newValue, animated: true)
      }
      .sensoryFeedback(.selection, trigger: centredID)
      // Grip and glide have different chips. Swapping them under a live
      // scroll offset leaves it pointing past the new content, so the row
      // looks empty until it is dragged; a fresh row per domain starts centred.
      .id(store.activeDomain)
      .onChange(of: store.activeDomain) { _, _ in
        isScrolling = false
        pendingSelection?.cancel()
      }
    }
  }

  private func centre(on id: String, animated: Bool) {
    if animated {
      withAnimation(.smooth(duration: 0.3)) { position.scrollTo(id: id, anchor: .center) }
    } else {
      position.scrollTo(id: id, anchor: .center)
    }
  }

  private func selectCentred() {
    guard let id = centredID, let choice = choices.first(where: { $0.id == id }) else { return }
    select(choice)
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
