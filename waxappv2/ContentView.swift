//
//  ContentView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 15/12/2025.
//

import CoreLocation
import Observation
import SwiftUI

enum Tabs {
  case waxes
  case about
}

struct ContentView: View {

  @Environment(StoreManager.self) private var storeManager: StoreManager
  @Environment(LocationStore.self) private var locStore
  @Environment(\.scenePhase) private var scenePhase

  @State private var selectedTab: Tabs = .waxes
  @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
  @State private var showTrialWarning = false

  /// Computed: Should paywall be shown?
  /// Shows when: onboarding done AND no access AND store is initialized
  private var shouldShowPaywall: Bool {
    hasSeenOnboarding && !storeManager.hasAccess && storeManager.isInitialized
  }

  /// Computed: Is user ready to use the app?
  /// Ready when: onboarding done AND has access
  private var isReadyForContent: Bool {
    hasSeenOnboarding && storeManager.hasAccess
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
    .onAppear {
      Task {
        await storeManager.refreshAll()
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        Task {
          await storeManager.updateAccessState()
        }
      }
    }
    .onChange(of: isReadyForContent) { wasReady, isNowReady in
      // When user becomes ready (has access after onboarding), enable location
      if !wasReady && isNowReady {
        enableLocationServices()
      }
    }
    .onChange(of: storeManager.accessState) { _, newStatus in
      guard storeManager.isInitialized else { return }

      // Show trial warning if applicable
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
    // MARK: PayWallView - non-dismissable when no access
    .sheet(isPresented: .constant(shouldShowPaywall)) {
      PaywallView()
        .interactiveDismissDisabled()
    }
    // MARK: OnboardingView
    .sheet(
      isPresented: Binding(
        get: { !hasSeenOnboarding },
        set: { if !$0 { hasSeenOnboarding = true } }
      )
    ) {
      OnboardingView(
        showOnboarding: Binding(
          get: { !hasSeenOnboarding },
          set: { if !$0 { hasSeenOnboarding = true } }
        )
      )
      .interactiveDismissDisabled()
    }
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

  // Location services DO work in previews!
  // The preview will request location permission and fetch real data

  ContentView()
    .environment(app.location)
    .environment(app.weather)
    .environment(app.waxSelection)
    .environment(app.recommendation)
    .environment(app.storeManager)
}
