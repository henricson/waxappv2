//
//  ContentView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 15/12/2025.
//

import SwiftUI
import Observation

enum Tabs {
    case waxes
    case about
}

struct ContentView: View {
    
    @Environment(StoreManager.self) private var storeManager: StoreManager

    @State private var selectedTab: Tabs = .waxes
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @State private var showTrialWarning = false
    @State private var showPaywall = false
    
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
        .onAppear {
            // Request location when preview appears
            // This will trigger the full chain: location → weather → recommendations
            app.location.requestLocation()
        }
}
