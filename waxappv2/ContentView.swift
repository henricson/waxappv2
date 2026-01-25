//
//  ContentView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 15/12/2025.
//

import SwiftUI

enum Tabs {
    case waxes
    case about
}

struct ContentView: View {
    @State private var selectedTab: Tabs = .waxes
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @EnvironmentObject var storeManager: StoreManager
    @State private var showTrialWarning = false
    @State private var showPaywall = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Wax", systemImage: "figure.skiing.crosscountry", value: .waxes) {
                MainView()
            }
            Tab("About", systemImage: "info.circle", value: .about) {
                AboutView()
            }
        }
        .onAppear() {
            Task {
                // Sync with CloudKit before checking trial status
                await storeManager.performLaunchSync()
                
                // Check trial status after sync and initialization complete
                checkTrialStatus()
            }
        }
        .onChange(of: storeManager.cachedTrialStatus) { oldStatus, newStatus in
            // Only show paywall if initialized and not purchased
            guard storeManager.isInitialized else { return }
            
            // Show paywall if trial expires
            if newStatus == .expired && !storeManager.isPurchased {
                showPaywall = true
            }
        }
        .onChange(of: storeManager.isInitialized) { _, initialized in
            // Check trial status once initialization completes
            if initialized {
                checkTrialStatus()
            }
        }
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
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
    
    private func checkTrialStatus() {
        // Skip if app is purchased
        if storeManager.isPurchased {
            return
        }
        
        // Only check trial status if StoreManager is fully initialized
        guard storeManager.isInitialized else { return }
        
        if case .warning = storeManager.trialStatus, !storeManager.isPurchased {
            showTrialWarning = true
        }
        
        // Show paywall if trial is expired
        if storeManager.trialStatus == .expired && !storeManager.isPurchased {
            showPaywall = true
        }
    }
}

#Preview {
    let app = AppState()
    ContentView()
        .environmentObject(app.location)
        .environmentObject(app.weather)
        .environmentObject(app.waxSelection)
        .environmentObject(app.recommendation)
        .environmentObject(app.storeManager)
}
