//
//  MainView.swift
//  waxappv2
//

import CoreLocation
import SwiftUI
import TipKit
import WeatherKit

#if canImport(UIKit)
  import UIKit
#endif

// MARK: - TipKit

struct GanttScrollTip: Tip {
  var title: Text {
    Text("Adjust Temperature", comment: "Tip title for Gantt scroll")
  }

  var message: Text? {
    Text(
      "Scroll horizontally to adjust the temperature and see different wax recommendations.",
      comment: "Tip message for Gantt scroll")
  }

  var image: Image? {
    Image(systemName: "hand.draw")
  }
}

// MARK: - Layout

private enum LayoutConstants {
  static let heroHeight: CGFloat = 306
  /// iPad: a taller hero, and a column that doesn't stretch edge to edge.
  static let regularHeroHeight: CGFloat = 420
  static let regularContentWidth: CGFloat = 760
  static let companionRowHeight: CGFloat = 52
}

// MARK: - MainView

struct MainView: View {
  @Environment(RecommendationStore.self) private var recStore
  @Environment(LocationStore.self) private var locStore
  @Environment(WeatherStore.self) private var weatherStore
  @Environment(WaxSelectionStore.self) private var waxStore
  @Environment(StoreManager.self) private var storeManager
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass

  // MARK: UI State

  @State private var showMapSelection = false
  @State private var showLocationPermissionAlert = false
  @State private var showWeatherErrorAlert = false
  @State private var showPaywall = false
  @State private var showWaxLibrary = false
  @State private var showSettings = false
  @State private var isUserInitiatedLocationRequest = false

  @Namespace private var glassNamespace

  private let scrollTip = GanttScrollTip()

  // MARK: Derived

  private var shouldShowPurchaseButton: Bool {
    storeManager.isInitialized && !storeManager.hasAccess
  }

  private var showAttribution: Bool {
    recStore.isSameAsWeatherKit && weatherStore.hasLoadedWeather
  }

  private var tintColor: Color {
    guard let top = recStore.topPick else { return .accentColor }
    return Color(hex: top.product.backgroundColor) ?? .accentColor
  }

  // MARK: Body

  var body: some View {
    NavigationStack {
      content
        .navigationTitle(locStore.location?.placeName ?? String(localized: "GetGrip"))
        #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar { toolbarContent }
        .navigationDestination(isPresented: $showWaxLibrary) {
          WaxSelectionView()
        }
        .sheet(isPresented: $showMapSelection) { MapSelectView() }
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .sheet(isPresented: $showSettings) { AboutView() }
        .task(id: locStore.location) {
          guard locStore.location != nil else { return }
          weatherStore.reset()
          let didLoad = await weatherStore.fetchWeather()
          if didLoad {
            // Demo mode pins temperature and snow type for reproducible
            // screenshots, so the weather must not overwrite them.
            if !DemoMode.isEnabled { recStore.syncFromWeather() }
          } else if weatherStore.fetchError != nil {
            showWeatherErrorAlert = true
          }
        }
        .onChange(of: waxStore.selectedSeriesIDs) { _, _ in
          recStore.reconcileSnowType()
        }
        .task {
          guard DemoMode.isEnabled, DemoMode.screen != nil else { return }
          // Let the root view settle; a destination set during the first
          // layout pass is dropped.
          try? await Task.sleep(for: .milliseconds(1500))
          switch DemoMode.screen {
          case "library": showWaxLibrary = true
          case "map": showMapSelection = true
          default: break
          }
        }
        .onChange(of: locStore.authorizationStatus, handleAuthorizationChange)
        .onChange(of: locStore.locationStatus, handleLocationStatusChange)
        .alert("Location Permission Denied", isPresented: $showLocationPermissionAlert) {
          locationPermissionAlertActions
        } message: {
          Text(
            "Please enable location services in settings, or select your position manually using the top left map button."
          )
        }
        .alert("Weather Data Unavailable", isPresented: $showWeatherErrorAlert) {
          weatherErrorAlertActions
        } message: {
          Text(
            "We couldn't reach a weather service. You can still set the temperature and snow type by hand below."
          )
        }
    }
  }
}

// MARK: - Content

extension MainView {

  fileprivate var content: some View {
    ZStack {
      backgroundGradient

      ScrollView(.vertical) {
        VStack(spacing: 16) {
          // On iPad the pick and its companions sit in a readable column;
          // the snow picker and the chart use the full width, where the
          // extra degrees on screen are genuinely useful.
          VStack(spacing: 16) {
            domainPicker
              .padding(.top, 4)

            heroSection
              .frame(
                height: horizontalSizeClass == .regular
                  ? LayoutConstants.regularHeroHeight : LayoutConstants.heroHeight)

            if recStore.isAdvancedMode, let top = recStore.topPick {
              RecommendationFactorsView(recommendation: top)
                .padding(.horizontal)
                .transition(.blurReplace)
            }

            alternativesSection
          }
          .frame(maxWidth: horizontalSizeClass == .regular ? LayoutConstants.regularContentWidth : .infinity)

          conditionsSection

          ganttSection

          attributionSection
        }
        .padding(.bottom, 32)
      }
      .scrollEdgeEffectStyle(.soft, for: .top)
    }
    .safeAreaInset(edge: .bottom) {
      floatingPurchaseButton
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
    .animation(.smooth(duration: 0.35), value: recStore.activeDomain)
    .animation(.smooth(duration: 0.35), value: recStore.topPick?.id)
    .animation(.smooth(duration: 0.3), value: shouldShowPurchaseButton)
  }

  // MARK: Background

  /// A neutral page with a restrained wash of the wax colour behind the hero.
  /// An earlier version tinted the whole screen, which drowned the content
  /// and fought with the product artwork.
  fileprivate var backgroundGradient: some View {
    ZStack(alignment: .top) {
      Color(.systemGroupedBackground)

      LinearGradient(
        stops: [
          .init(color: tintColor.opacity(colorScheme == .dark ? 0.30 : 0.22), location: 0.0),
          .init(color: tintColor.opacity(colorScheme == .dark ? 0.12 : 0.08), location: 0.35),
          .init(color: .clear, location: 0.62),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
    }
    .ignoresSafeArea()
    .animation(.smooth(duration: 0.6), value: tintColor)
  }

  // MARK: Grip / glide picker

  fileprivate var domainPicker: some View {
    // Two adjacent glass capsules fuse into one blob through
    // GlassEffectContainer's proximity merging, which reads as a single
    // malformed shape. One capsule with a sliding selection is both calmer
    // and the standard idiom for a two-way switch.
    HStack(spacing: 0) {
      ForEach(WaxDomain.allCases) { domain in
        let isActive = recStore.activeDomain == domain

        Button {
          withAnimation(.smooth(duration: 0.3)) {
            recStore.activeDomain = domain
            recStore.reconcileSnowType()
          }
        } label: {
          Label {
            Text(domain.title)
          } icon: {
            // A concrete colour: on glass, dynamic `.primary` turns vibrant
            // and a custom shape renders washed-out grey next to the text.
            DomainGlyph(
              domain: domain,
              color: isActive || colorScheme == .dark ? .white : .black)
          }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .background {
          if isActive {
            Capsule()
              .fill(tintColor.gradient)
              .matchedGeometryEffect(id: "domainSelection", in: glassNamespace)
          }
        }
        .accessibilityIdentifier("domain_\(domain.rawValue)")
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
      }
    }
    .padding(4)
    .frame(maxWidth: 300)
    .glassEffect(.regular, in: .capsule)
  }

  // MARK: Hero

  @ViewBuilder
  fileprivate var heroSection: some View {
    if recStore.hasNoVisibleSeries {
      emptyLibraryHero
    } else if let top = recStore.topPick {
      HeaderCanView(recommendation: top, preparation: recStore.preparation)
        .id(top.id)
        .transition(.blurReplace.combined(with: .scale(0.94)))
    } else {
      outOfRangeHero
    }
  }

  fileprivate var emptyLibraryHero: some View {
    ContentUnavailableView {
      Label("No waxes selected", systemImage: "square.stack.3d.up.slash")
    } description: {
      Text("Turn on at least one series to see recommendations.")
    } actions: {
      Button("Open wax library") { showWaxLibrary = true }
        .buttonStyle(.glassProminent)
    }
  }

  fileprivate var outOfRangeHero: some View {
    VStack(spacing: 18) {
      Image(systemName: "thermometer.medium.slash")
        .font(.system(size: 34, weight: .light))
        .foregroundStyle(.secondary)

      Text("Nothing in your library covers \(recStore.effectiveTemperature)°C")
        .font(.headline)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      if let target = recStore.nearestRecommendedTemperature(
        from: recStore.effectiveTemperature)
      {
        Button {
          withAnimation(.smooth(duration: 0.35)) {
            recStore.effectiveTemperature = target
          }
        } label: {
          Label(
            "Jump to \(target)°C",
            systemImage: target > recStore.effectiveTemperature
              ? "arrow.right" : "arrow.left"
          )
        }
        .buttonStyle(.glass)
        .accessibilityHint(
          "Moves the temperature scale to the nearest range with recommendations")
      }
    }
  }

  // MARK: Alternatives

  /// The other waxes that cover this temperature, in a row of fixed height
  /// that never appears or vanishes, so nothing below it moves. The base
  /// layer is not an alternative and sits with the pick in the hero.
  fileprivate var alternativesSection: some View {
    let alternatives = recStore.alternatives

    return VStack(alignment: .leading, spacing: 8) {
      SectionHeader("Also works")
        .padding(.top, 8)

      ScrollView(.horizontal) {
        HStack(spacing: 10) {
          ForEach(alternatives) { alternative in
            AlternativeChip(recommendation: alternative)
          }
          if alternatives.isEmpty {
            Text("Nothing else in your library covers this")
              .font(.footnote)
              .foregroundStyle(.secondary)
              .padding(.vertical, 8)
          }
        }
        .padding(.horizontal)
        .animation(.smooth(duration: 0.25), value: alternatives.map(\.id))
      }
      .scrollIndicators(.hidden)
      .frame(height: LayoutConstants.companionRowHeight)
    }
  }

  // MARK: Conditions

  fileprivate var conditionsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        SectionHeader("Snow")
        Spacer(minLength: 8)
        LocationSourceIndicator(
          isManualOverride: locStore.locationStatus == .manual_override,
          isUsingWeatherData: recStore.isSameAsWeatherKit
        )
        .padding(.trailing)
      }

      SnowTypeButtons(store: recStore)
        .frame(height: 46)
    }
    .padding(.top, 8)
    .animation(.smooth(duration: 0.3), value: recStore.isSameAsWeatherKit)
  }

  // MARK: Gantt

  fileprivate var ganttSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      SectionHeader("Temperature")

      // The tip used to sit on top of the chart it was describing.
      if !DemoMode.isEnabled {
        TipView(scrollTip, arrowEdge: .bottom)
          .padding(.horizontal)
      }

      Gantt(selectedWaxes: recStore.candidates)
    }
    .padding(.top, 8)
  }

  // MARK: Attribution

  @ViewBuilder
  fileprivate var attributionSection: some View {
    if showAttribution {
      WeatherAttributionView()
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .transition(.opacity)
    }
  }

  // MARK: Purchase

  @ViewBuilder
  fileprivate var floatingPurchaseButton: some View {
    if shouldShowPurchaseButton {
      FloatingPurchaseButton(
        subtitle: storeManager.isEligibleForIntroOffer
          ? String(localized: "Start your 14-day free trial")
          : String(localized: "Unlock full access"),
        actionTitle: storeManager.isEligibleForIntroOffer
          ? String(localized: "Start trial")
          : String(localized: "Subscribe")
      ) {
        showPaywall = true
      }
    }
  }
}

// MARK: - Toolbar

extension MainView {
  @ToolbarContentBuilder
  fileprivate var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button {
        showMapSelection = true
      } label: {
        Image(systemName: "map")
      }
      .accessibilityIdentifier("mapButton")
      .accessibilityLabel("Choose location on map")
      .tint(
        locStore.locationStatus == .manual_override && recStore.isSameAsWeatherKit
          ? .accentColor : .primary
      )
    }

    ToolbarItem(placement: .topBarTrailing) {
      Button(action: handleLocationButtonTap) {
        Image(systemName: "location.fill")
      }
      .accessibilityIdentifier("locationButton")
      .accessibilityLabel("Use my location")
      .tint(
        recStore.isSameAsWeatherKit && locStore.locationStatus != .manual_override
          ? .accentColor : .primary
      )
    }

    ToolbarSpacer(.fixed, placement: .topBarTrailing)

    ToolbarItem(placement: .topBarTrailing) {
      Button {
        showSettings = true
      } label: {
        Image(systemName: "gearshape")
      }
      .accessibilityIdentifier("settingsButton")
      .accessibilityLabel("Settings")
    }
  }

}

// MARK: - Actions

extension MainView {
  fileprivate func handleLocationButtonTap() {
    switch locStore.authorizationStatus {
    case .denied, .restricted:
      showLocationPermissionAlert = true
    case .notDetermined:
      isUserInitiatedLocationRequest = true
      locStore.requestAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      isUserInitiatedLocationRequest = true
      recStore.syncFromWeather()
      locStore.requestLocation()
    @unknown default:
      break
    }
  }

  fileprivate func handleAuthorizationChange(
    _ oldStatus: CLAuthorizationStatus, _ newStatus: CLAuthorizationStatus
  ) {
    guard isUserInitiatedLocationRequest else { return }

    if newStatus == .denied || newStatus == .restricted {
      showLocationPermissionAlert = true
      isUserInitiatedLocationRequest = false
    }
  }

  fileprivate func handleLocationStatusChange(
    _ oldStatus: LocationStatus, _ newStatus: LocationStatus
  ) {
    guard isUserInitiatedLocationRequest else { return }

    switch newStatus {
    case .denied:
      showLocationPermissionAlert = true
      isUserInitiatedLocationRequest = false
    case .active:
      isUserInitiatedLocationRequest = false
    default:
      break
    }
  }
}

// MARK: - Alert Actions

extension MainView {
  @ViewBuilder
  fileprivate var locationPermissionAlertActions: some View {
    Button("Cancel", role: .cancel) {}
    #if canImport(UIKit)
      Button("Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url)
        }
      }
    #endif
  }

  @ViewBuilder
  fileprivate var weatherErrorAlertActions: some View {
    Button("Set manually") { showWeatherErrorAlert = false }
    Button("Retry") {
      Task {
        if await weatherStore.fetchWeather() {
          recStore.syncFromWeather()
        }
      }
    }
    Button("Cancel", role: .cancel) {}
  }
}

// MARK: - Section header

/// One style for every section label on the page, so the order reads as
/// hero → alternatives → snow → temperature at a glance.
private struct SectionHeader: View {
  let title: LocalizedStringKey

  init(_ title: LocalizedStringKey) { self.title = title }

  var body: some View {
    Text(title)
      .font(.footnote.weight(.semibold))
      .textCase(.uppercase)
      .foregroundStyle(.secondary)
      .padding(.horizontal)
      .accessibilityAddTraits(.isHeader)
  }
}

// MARK: - Alternative chip

private struct AlternativeChip: View {
  let recommendation: WaxRecommendation

  private var product: WaxProduct { recommendation.product }

  var body: some View {
    HStack(spacing: 8) {
      WaxIcon(product: product)
        .frame(width: 18, height: 26)

      VStack(alignment: .leading, spacing: 0) {
        Text(product.code)
          .font(.caption.weight(.semibold))
        Text(product.brand.displayName)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(.background.secondary, in: .capsule)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(product.name), \(product.brand.displayName)")
  }
}

// MARK: - WeatherAttributionView

struct WeatherAttributionView: View {
  @Environment(\.colorScheme) private var colorScheme
  @State private var attribution: WeatherAttribution?

  private var logoURL: URL? {
    guard let attribution else { return nil }
    return colorScheme == .dark
      ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
  }

  var body: some View {
    VStack(spacing: 6) {
      if let logoURL {
        AsyncImage(url: logoURL) { image in
          image.resizable().scaledToFit().frame(height: 14)
        } placeholder: {
          appleWeatherFallback
        }
      } else {
        appleWeatherFallback
      }

      Text("Weather data is adjusted for snow conditions")
        .font(.caption2)
        .foregroundStyle(.secondary)

      if let attribution {
        Link(destination: attribution.legalPageURL) {
          HStack(spacing: 4) {
            Text("Other data sources")
            Image(systemName: "arrow.up.right")
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
        }
      }
    }
    .frame(minHeight: 44)
    .task {
      guard attribution == nil else { return }
      attribution = try? await WeatherService.shared.attribution
    }
  }

  private var appleWeatherFallback: some View {
    HStack(spacing: 4) {
      Image(systemName: "apple.logo")
      Text("Weather").fontWeight(.medium)
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
  }
}

// MARK: - Preview

#Preview {
  let app = AppState()
  MainView()
    .environment(app.location)
    .environment(app.weather)
    .environment(app.recommendation)
    .environment(app.waxSelection)
    .environment(app.storeManager)
}
