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
                // Fetch trial start date from CloudKit
                await storeManager.performLaunchSync()
            }
            
            // Request location immediately for returning users
            if hasSeenOnboarding && !hasRequestedInitialLocation {
                requestInitialLocation()
            }
        }
        .onChange(of: hasSeenOnboarding) { oldValue, newValue in
            // When onboarding is dismissed (false -> true), request location
            if !oldValue && newValue && !hasRequestedInitialLocation {
                requestInitialLocation()
            }
        }
        // MARK: Trial is about to end
        .onChange(of: storeManager.trialStatus) { _, newStatus in
            // Only react if initialized and not purchased
            guard storeManager.isInitialized, !storeManager.isPurchased else { return }
            
            switch newStatus {
            case .warning:
                showTrialWarning = true
            case .expired:
                showPaywall = true
            case .active:
                break
            }
        }
        // MARK: Trial ending alert
        .alert("Trial Ending Soon", isPresented: $showTrialWarning) {
            Button("OK", role: .cancel) { }
            Button("Buy Now") {
                showPaywall = true
            }
        } message: {
            if case .warning(let days) = storeManager.trialStatus {
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
    
    private func requestInitialLocation() {
        hasRequestedInitialLocation = true
        
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
