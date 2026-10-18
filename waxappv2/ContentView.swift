//
//  ContentView.swift
//  waxappv2
//

import CoreLocation
import SwiftUI

enum Tabs: Hashable {
  case waxes
  case about
}

struct ContentView: View {

  @Environment(StoreManager.self) private var storeManager
  @Environment(LocationStore.self) private var locStore
  @Environment(WaxSelectionStore.self) private var waxStore
  @Environment(RecommendationStore.self) private var recStore
  @Environment(\.scenePhase) private var scenePhase

  @State private var selectedTab: Tabs = .waxes
  @State private var showTrialWarning = false

  /// Onboarding ownership lives in `WaxSelectionStore`, because finishing it
  /// is what produces the user's wax selection. Upgraders from a version
  /// without gliders or Rode are flagged for onboarding during migration.
  private var isOnboarding: Bool { waxStore.needsOnboarding }

  /// Paywall shows once onboarding is done and the user has no access.
  private var shouldShowPaywall: Bool {
    !isOnboarding && !storeManager.hasAccess && storeManager.isInitialized
  }

  private var isReadyForContent: Bool {
    !isOnboarding && storeManager.hasAccess
  }

  private var onboardingBinding: Binding<Bool> {
    Binding(
      get: { isOnboarding },
      set: { if !$0 { waxStore.markOnboardingComplete() } }
    )
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      Tab("Predictions", systemImage: "figure.skiing.crosscountry", value: .waxes) {
        MainView()
      }
      Tab("About", systemImage: "info.circle", value: .about) {
        AboutView()
      }
    }
    .tabBarMinimizeBehavior(.onScrollDown)
    .onAppear {
      Task { await storeManager.refreshAll() }
      publishWidgetState()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        Task { await storeManager.refreshAll(force: true) }
      }
      if newPhase == .background { publishWidgetState() }
    }
    // Keep the widgets' copy of the library, access and place current.
    .onChange(of: widgetInputs) { _, _ in publishWidgetState() }
    .onOpenURL { url in
      guard let domain = WaxDomain(appURL: url) else { return }
      selectedTab = .waxes
      recStore.activeDomain = domain
      recStore.reconcileSnowType()
    }
    .onChange(of: isReadyForContent) { wasReady, isNowReady in
      if !wasReady && isNowReady {
        enableLocationServices()
      }
    }
    .onChange(of: storeManager.accessState) { _, newStatus in
      guard storeManager.isInitialized else { return }
      if case .trialActive(let daysLeft) = newStatus, daysLeft > 0, daysLeft <= 4 {
        showTrialWarning = true
      }
    }
    // MARK: Trial ending alert
    .alert("Trial Ending Soon", isPresented: $showTrialWarning) {
      Button("OK", role: .cancel) {}
    } message: {
      if let days = storeManager.trialDaysRemaining {
        Text("You have \(days) days left in your free trial.")
      } else {
        Text("Your free trial is ending soon.")
      }
    }
    // MARK: Paywall — non-dismissable when there is no access
    .sheet(isPresented: .constant(shouldShowPaywall)) {
      PaywallView()
        .interactiveDismissDisabled()
    }
    // MARK: Onboarding
    .fullScreenCover(isPresented: onboardingBinding) {
      OnboardingView(isPresented: onboardingBinding)
    }
    #if DEBUG
      .overlay {
        if DemoMode.showsArtCatalogue {
          WaxArtCatalogue(domain: DemoMode.domain, isLarge: DemoMode.artCatalogueIsLarge)
        }
      }
    #endif
  }

  // MARK: - Widgets

  /// Everything the widgets read, so one `onChange` covers it.
  private var widgetInputs: [String] {
    [
      waxStore.selectedSeriesIDs.sorted().joined(separator: ","),
      waxStore.hiddenProductIDs.sorted().joined(separator: ","),
      "\(storeManager.isInitialized)-\(storeManager.hasAccess)",
      locStore.location.map { "\($0.lat),\($0.lon),\($0.placeName ?? "")" } ?? "",
      recStore.activeDomain.rawValue,
    ]
  }

  private func publishWidgetState() {
    WidgetBridge.publish(
      selection: waxStore, storeManager: storeManager,
      location: locStore, recommendation: recStore)
  }

  // MARK: - Location Services

  private func enableLocationServices() {
    locStore.isLocationRequestEnabled = true

    switch locStore.authorizationStatus {
    case .notDetermined:
      locStore.requestAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      locStore.requestLocation()
    case .denied, .restricted:
      break
    @unknown default:
      break
    }
  }
}

#Preview {
  let app = AppState()

  ContentView()
    .environment(app.location)
    .environment(app.weather)
    .environment(app.waxSelection)
    .environment(app.recommendation)
    .environment(app.storeManager)
}
