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
    
    var body: some View {
        Group {
            if storeManager.trialStatus == .expired && !storeManager.isPurchased {
                PaywallView()
            } else {
                TabView(selection: $selectedTab) {
                    Tab("Wax", systemImage: "snow", value: .waxes) {
                        MainView()
                    }
                    Tab("About", systemImage: "info.circle", value: .about) {
                        AboutView()
                    }
                }
                .onAppear {
                    checkTrialStatus()
                }
                .alert("Trial Ending Soon", isPresented: $showTrialWarning) {
                    Button("OK", role: .cancel) { }
                    Button("Buy Now") {
                        // Present paywall if needed, or navigate to it
                    }
                } message: {
                    if case .warning(let days) = storeManager.trialStatus {
                        Text("You have \(days) days left in your free trial.")
                    } else {
                        Text("Your free trial is ending soon.")
                    }
                }
            }
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
        if case .warning = storeManager.trialStatus, !storeManager.isPurchased {
            showTrialWarning = true
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
