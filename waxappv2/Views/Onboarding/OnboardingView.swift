//
//  OnboardingView.swift
//  waxappv2
//
//  Introduces the app, explains how a recommendation is made, and lets the
//  skier pick the wax lines they actually own. Shown to new installs and to
//  anyone upgrading from a version that predates gliders and Rode.
//

import StoreKit
import SwiftUI

struct OnboardingView: View {
  @Binding var isPresented: Bool

  @Environment(WaxSelectionStore.self) private var waxStore
  @Environment(StoreManager.self) private var storeManager

  enum Page: Int, CaseIterable, Identifiable {
    case welcome
    case howItWorks
    case library
    case access

    var id: Int { rawValue }
  }

  @State private var page: Page = DemoMode.isEnabled
    ? (Page(rawValue: DemoMode.onboardingPage) ?? .welcome)
    : .welcome
  @Namespace private var glassNamespace

  var body: some View {
    ZStack {
      backdrop

      VStack(spacing: 0) {
        // Skip sits in its own row so it never covers a page title.
        HStack {
          Spacer()
          if page != .access {
            skipButton.transition(.blurReplace)
          }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.top, 4)

        TabView(selection: $page) {
          WelcomePage().tag(Page.welcome)
          HowItWorksPage().tag(Page.howItWorks)
          LibraryPage().tag(Page.library)
          AccessPage(hasAccess: storeManager.hasAccess).tag(Page.access)
        }
        #if os(iOS)
          .tabViewStyle(.page(indexDisplayMode: .never))
        #endif

        footer
      }
    }
    .animation(.smooth(duration: 0.3), value: page)
    .interactiveDismissDisabled()
  }

  // MARK: - Skip

  /// Leaves with the regional kit already selected; nothing is lost by
  /// skipping, and the paywall still appears afterwards if it is needed.
  private var skipButton: some View {
    Button("Skip") {
      waxStore.markOnboardingComplete()
      isPresented = false
    }
    .font(.subheadline.weight(.semibold))
    .padding(.horizontal, 16)
    .padding(.vertical, 9)
    .glassEffect(.regular.interactive(), in: .capsule)
    .accessibilityIdentifier("onboardingSkipButton")
    .accessibilityHint(Text("Onboarding_Skip_Hint"))
  }

  // MARK: - Backdrop

  private var backdrop: some View {
    LinearGradient(
      colors: [
        Color(hex: "#2C68BD")?.opacity(0.35) ?? .blue.opacity(0.3),
        Color(hex: "#3FC1D3")?.opacity(0.18) ?? .teal.opacity(0.2),
        .clear,
      ],
      startPoint: .topLeading,
      endPoint: .bottom
    )
    .ignoresSafeArea()
  }

  // MARK: - Footer

  private var footer: some View {
    VStack(spacing: 16) {
      pageDots

      GlassEffectContainer(spacing: 12) {
        HStack(spacing: 12) {
          if page != .welcome {
            Button {
              withAnimation(.smooth(duration: 0.3)) { goBack() }
            } label: {
              Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .frame(width: 24, height: 24)
                .padding(14)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .glassEffectID("back", in: glassNamespace)
            .accessibilityLabel("Back")
            .transition(.blurReplace)
          }

          Button {
            advance()
          } label: {
            Text(primaryTitle)
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 16)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.white)
          .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
          .glassEffectID("primary", in: glassNamespace)
          .accessibilityIdentifier("onboardingPrimaryButton")
        }
      }
      .animation(.smooth(duration: 0.3), value: page)
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 20)
  }

  private var pageDots: some View {
    HStack(spacing: 7) {
      ForEach(Page.allCases) { p in
        Capsule()
          .fill(p == page ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
          .frame(width: p == page ? 22 : 7, height: 7)
      }
    }
    .animation(.smooth(duration: 0.3), value: page)
    .accessibilityHidden(true)
  }

  private var primaryTitle: String {
    switch page {
    case .welcome, .howItWorks:
      return String(localized: "Continue")
    case .library:
      return String(localized: "Looks good")
    case .access:
      return storeManager.hasAccess
        ? String(localized: "Start using GetGrip")
        : String(localized: "Start free trial")
    }
  }

  // MARK: - Navigation

  private func advance() {
    switch page {
    case .welcome:
      withAnimation(.smooth(duration: 0.35)) { page = .howItWorks }
    case .howItWorks:
      withAnimation(.smooth(duration: 0.35)) { page = .library }
    case .library:
      withAnimation(.smooth(duration: 0.35)) { page = .access }
    case .access:
      Task { await finish() }
    }
  }

  private func goBack() {
    guard let previous = Page(rawValue: page.rawValue - 1) else { return }
    page = previous
  }

  @MainActor
  private func finish() async {
    if !storeManager.hasAccess, let product = storeManager.primaryProduct {
      await storeManager.purchase(product)
    }
    waxStore.markOnboardingComplete()
    isPresented = false
  }
}

// MARK: - Page 1: Welcome

private struct WelcomePage: View {
  var body: some View {
    OnboardingScaffold(
      title: String(localized: "Welcome to GetGrip"),
      subtitle: String(
        localized:
          "Grip and glide recommendations for cross-country skis, built from the weather where you ski."
      )
    ) {
      WaxShelf(products: heroProducts, height: 250)
        .frame(maxWidth: .infinity)
    }
  }

  /// A tin, a klister tube and a glide pack from each brand's everyday
  /// range — what a skier's wax box actually looks like.
  private var heroProducts: [WaxProduct] {
    [
      "swix.KX65", "swix.V40", "swix.PS7", "rode.P40", "swix.HS8L",
    ].compactMap(WaxCatalog.product(withID:))
  }
}

/// Products standing side by side at their real proportions, settling into
/// place one after another. Scales down as a whole to fit the width, so no
/// container is ever cropped at the screen edge.
struct WaxShelf: View {
  let products: [WaxProduct]
  var height: CGFloat

  @State private var appeared = false

  private let spacingRatio: CGFloat = 0.05

  /// Width the row needs at a given height.
  private func width(at height: CGFloat) -> CGFloat {
    let items = products.reduce(CGFloat(0)) {
      $0 + height * WaxIcon.shelfHeight(for: $1) * WaxIcon.aspect(for: $1)
    }
    return items + height * spacingRatio * CGFloat(max(products.count - 1, 0))
  }

  var body: some View {
    GeometryReader { geo in
      let fitted = min(height, height * geo.size.width / max(width(at: height), 1))

      HStack(alignment: .bottom, spacing: fitted * spacingRatio) {
        ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
          let itemHeight = fitted * WaxIcon.shelfHeight(for: product)
          WaxIcon(product: product)
            .frame(width: itemHeight * WaxIcon.aspect(for: product), height: itemHeight)
            .shadow(color: .black.opacity(0.14), radius: 12, y: 8)
            .offset(y: appeared ? 0 : 24)
            .opacity(appeared ? 1 : 0)
            .animation(
              .spring(response: 0.6, dampingFraction: 0.78).delay(Double(index) * 0.07),
              value: appeared)
        }
      }
      .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
    }
    .frame(height: height)
    .onAppear { appeared = true }
    .accessibilityHidden(true)
  }
}

// MARK: - Page 2: How it works

private struct HowItWorksPage: View {
  var body: some View {
    OnboardingScaffold(
      title: String(localized: "How it works"),
      subtitle: String(
        localized:
          "We read ten days of weather for your location, work out what the snow has become, and match it to the wax you own."
      )
    ) {
      VStack(spacing: 14) {
        StepRow(
          number: 1,
          icon: "location.fill",
          title: String(localized: "Step_Location_Title"),
          detail: String(localized: "Step_Location_Detail")
        )
        StepRow(
          number: 2,
          icon: "snowflake",
          title: String(localized: "Step_Snow_Title"),
          detail: String(localized: "Step_Snow_Detail")
        )
        StepRow(
          number: 3,
          icon: "checkmark.seal.fill",
          title: String(localized: "Step_Match_Title"),
          detail: String(localized: "Step_Match_Detail")
        )
      }
      .padding(.horizontal, 4)
    }
  }
}

private struct StepRow: View {
  let number: Int
  let icon: String
  let title: String
  let detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      ZStack {
        Circle()
          .fill(.tint.opacity(0.15))
          .frame(width: 38, height: 38)
        Image(systemName: icon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.tint)
      }

      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 0)
    }
    .padding(14)
    .glassEffect(.regular, in: .rect(cornerRadius: 18))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Step \(number). \(title). \(detail)")
  }
}

// MARK: - Page 3: Library multi-select

private struct LibraryPage: View {
  @Environment(WaxSelectionStore.self) private var store
  @State private var showsRaceLines = false

  private let region = RegionalWaxKit.Region.current

  var body: some View {
    OnboardingScaffold(
      title: String(localized: "Pick your wax"),
      subtitle: String(localized: "Onboarding_Library_Subtitle"),
      scrollsContent: true
    ) {
      VStack(alignment: .leading, spacing: 20) {
        RegionKitBanner(region: region)

        ForEach(WaxDomain.allCases) { domain in
          VStack(alignment: .leading, spacing: 8) {
            Label { Text(domain.title) } icon: { DomainGlyph(domain: domain) }
              .font(.footnote.weight(.semibold))
              .textCase(.uppercase)
              .foregroundStyle(.secondary)

            ForEach(series(in: domain, advanced: false)) { series in
              SeriesToggleCard(series: series)
            }
          }
        }

        // Race lines are folded away: an everyday skier never needs them,
        // and a racer knows to look.
        DisclosureGroup(isExpanded: $showsRaceLines.animation(.smooth(duration: 0.3))) {
          VStack(spacing: 8) {
            ForEach(WaxCatalog.series.filter(\.isAdvanced)) { series in
              SeriesToggleCard(series: series)
            }
          }
          .padding(.top, 8)
        } label: {
          Label("Race lines", systemImage: "flag.checkered")
            .font(.subheadline.weight(.semibold))
        }
        .tint(.primary)
      }
      .padding(.bottom, 8)
    }
  }

  private func series(in domain: WaxDomain, advanced: Bool) -> [WaxSeries] {
    WaxCatalog.series.filter { $0.domain == domain && $0.isAdvanced == advanced }
  }
}

/// Says plainly that the ticked lines were chosen for the user's country,
/// and offers a way back to them after edits.
private struct RegionKitBanner: View {
  @Environment(WaxSelectionStore.self) private var store
  let region: RegionalWaxKit.Region

  private var kit: Set<String> { RegionalWaxKit.seriesIDs(for: region) }
  private var isUsingKit: Bool { store.selectedSeriesIDs == kit }

  private var title: String {
    if let country = RegionalWaxKit.countryName(for: region) {
      return String(localized: "Picked for skiers in \(country)")
    }
    return String(localized: "A sensible everyday kit")
  }

  private var detail: String {
    if let country = RegionalWaxKit.countryName(for: region) {
      return String(localized: "Onboarding_Kit_Detail_Country \(country)")
    }
    return String(localized: "Onboarding_Kit_Detail")
  }

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: "sparkles")
        .font(.title3)
        .foregroundStyle(.tint)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)

        if !isUsingKit {
          Button("Use the recommended kit") {
            withAnimation(.smooth(duration: 0.3)) { store.resetToDefaults() }
          }
          .font(.caption.weight(.semibold))
          .padding(.top, 2)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .background(.tint.opacity(0.10), in: .rect(cornerRadius: 18))
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Page 4: Access

private struct AccessPage: View {
  let hasAccess: Bool
  @Environment(StoreManager.self) private var storeManager
  @Environment(WaxSelectionStore.self) private var waxStore

  private var subtitle: String {
    if hasAccess {
      return String(localized: "Your subscription is active. Enjoy full access to GetGrip.")
    }
    if let lifetime = storeManager.lifetimeProduct {
      return String(localized: "Onboarding_Access_WithLifetime \(lifetime.displayPrice)")
    }
    return String(
      localized:
        "Try everything free for 14 days. After that, a subscription keeps full access — cancel any time."
    )
  }

  var body: some View {
    OnboardingScaffold(
      title: hasAccess
        ? String(localized: "You're all set")
        : String(localized: "Get started for free"),
      subtitle: subtitle
    ) {
      WaxShelf(products: shelf, height: 230)
        .frame(maxWidth: .infinity)
    }
  }

  /// The user's own kit, so the last thing they see is what they picked.
  private var shelf: [WaxProduct] {
    waxStore.selectedSeries.prefix(5).compactMap { series in
      let products = WaxCatalog.products(inSeries: series.id).filter { !$0.kind.isPreparation }
      return products.isEmpty ? nil : products[products.count / 2]
    }
  }
}

// MARK: - Shared page scaffold

private struct OnboardingScaffold<Content: View>: View {
  let title: String
  let subtitle: String
  var scrollsContent: Bool = false
  @ViewBuilder var content: Content

  var body: some View {
    VStack(spacing: 0) {
      if scrollsContent {
        // Selection pages lead with the copy, then scroll the list.
        titleBlock
          .padding(.top, 8)
          .padding(.bottom, 18)

        ScrollView {
          content
            .padding(.horizontal, 22)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
      } else {
        // Story pages lead with the artwork, as Apple's own onboarding does.
        Spacer(minLength: 12)

        content
          .padding(.horizontal, 22)
          .frame(maxHeight: .infinity)

        Spacer(minLength: 12)

        titleBlock
          .padding(.bottom, 8)
      }
    }
  }

  private var titleBlock: some View {
    VStack(spacing: 10) {
      Text(title)
        .font(.largeTitle.bold())
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.8)
        .fixedSize(horizontal: false, vertical: true)

      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 28)
  }
}

// MARK: - Preview

#Preview {
  let app = AppState()
  return OnboardingView(isPresented: .constant(true))
    .environment(app.waxSelection)
    .environment(app.storeManager)
}
