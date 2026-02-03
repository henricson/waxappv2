//
//  ContentView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 15/12/2025.
//

import SwiftUI
import Observation
import CoreLocation

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
    @State private var showPaywall = false
    @State private var hasRequestedInitialLocation = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Predictions", systemImage: "figure.skiing.crosscountry", value: .waxes) {
                MainView()
            }
            Tab("About", systemImage: "info.circle", value: .about) {
                AboutView()
            }
        }
        .onAppear() {
            Task {
                await storeManager.refreshAll()
            }
            
            // Request location immediately for returning users who have access
            if hasSeenOnboarding && storeManager.hasAccess && !hasRequestedInitialLocation {
                enableAndRequestLocation()
            }
        }
        .onChange(of: hasSeenOnboarding) { oldValue, newValue in
            // When onboarding is dismissed, show paywall if no access
            if !oldValue && newValue && !storeManager.hasAccess {
                showPaywall = true
            }
            // If user has access (or gets it during onboarding), request location
            if !oldValue && newValue && storeManager.hasAccess && !hasRequestedInitialLocation {
                enableAndRequestLocation()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await storeManager.updateAccessState()
                }
            }
        }
        // MARK: Trial is about to end
        .onChange(of: storeManager.accessState) { _, newStatus in
            guard storeManager.isInitialized else { return }

            if case .trialActive(let daysLeft) = newStatus, daysLeft > 0, daysLeft <= 4 {
                showTrialWarning = true
            }

            if !storeManager.hasAccess, hasSeenOnboarding {
                showPaywall = true
            }

            if storeManager.hasAccess {
                showPaywall = false
                // User now has access - enable and request location if onboarding is done
                if hasSeenOnboarding && !hasRequestedInitialLocation {
                    enableAndRequestLocation()
                }
            }
        }
        // MARK: Trial ending alert
        .alert("Trial Ending Soon", isPresented: $showTrialWarning) {
            Button("OK", role: .cancel) { }
            Button("Subscribe") {
                showPaywall = true
            }
        } message: {
            if let days = storeManager.trialDaysRemaining {
                Text("You have \(days) days left in your free trial.")
            } else {
                Text("Your free trial is ending soon.")
            }
        }
        // MARK: PayWallView
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // MARK: OnboardingView
        .sheet(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { if !$0 { hasSeenOnboarding = true } }
        )) {
            OnboardingView(showOnboarding: Binding(
                get: { !hasSeenOnboarding },
                set: { if !$0 { hasSeenOnboarding = true } }
            ))
            .interactiveDismissDisabled()
        }
    }
    
    // MARK: - Location Request
    
    /// Enables location requests and triggers the initial location fetch.
    /// Should only be called after onboarding AND paywall are dismissed.
    private func enableAndRequestLocation() {
        hasRequestedInitialLocation = true
        locStore.isLocationRequestEnabled = true
        
        // Check current authorization status
        switch locStore.authorizationStatus {
        case .notDetermined:
            // Request authorization (will trigger location request in LocationStore delegate)
            locStore.requestAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            // Already authorized, request location directly
            locStore.requestLocation()
        case .denied, .restricted:
            // Don't request - user has already denied or is restricted
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
