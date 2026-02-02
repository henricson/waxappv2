//
//  AboutView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 07/01/2026.
//

import SwiftUI
import TipKit
import StoreKit

struct AboutView: View {
    @Environment(StoreManager.self) private var storeManager
    @State private var showPaywall = false
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        NavigationStack {
            List {
                Section("Subscription status") {
                    switch storeManager.accessState {
                    case .loading:
                        Label("Checking subscription…", systemImage: "clock")
                            .foregroundStyle(.secondary)
                    case .trialActive(let daysLeft):
                        Label("Free Trial Active", systemImage: "clock")
                            .foregroundStyle(.green)
                        Text("\(daysLeft) days left in trial")
                            .font(.subheadline)
                            .foregroundStyle(daysLeft <= 4 ? .red : .green)
                            .accessibilityLabel("\(daysLeft) days left in trial")
                    case .subscribed:
                        Label("Subscription active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    case .gracePeriod:
                        Label("Subscription in grace period", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    case .billingRetry:
                        Label("Payment issue", systemImage: "creditcard.trianglebadge.exclamationmark")
                            .foregroundStyle(.orange)
                    case .expired, .revoked, .notSubscribed:
                        Label("No active subscription", systemImage: "lock")
                            .foregroundStyle(.secondary)

                        Button {
                            showPaywall = true
                        } label: {
                            Label("Start free trial", systemImage: "arrow.up.circle")
                        }
                    }

                    if storeManager.hasAccess {
                        Button {
                            Task {
                                await showManageSubscriptions()
                            }
                        } label: {
                            Label("Manage Subscription", systemImage: "gearshape")
                        }
                    }
                }

                Section {
                    NavigationLink {
                        WaxSelectionView()
                    } label: {
                        Label("Visible waxes", systemImage: "checklist")
                    }
                }

                Section("Developer") {
                    Link(destination: URL(string: "https://www.squarewave.no")!) {
                        Text("Square Wave AS")
                    }
                }

                Section("Legal") {
                    Link(destination: URL(string: "https://www.squarewave.no/apps/getgrip/terms")!) {
                        Text("Terms of Service")
                    }
                    Link(destination: URL(string: "https://www.squarewave.no/apps/getgrip/privacy")!) {
                        Text("Privacy Policy")
                    }
                }
            }
            .navigationTitle("About")
#if os(iOS)

            .navigationBarTitleDisplayMode(.inline)
            #endif
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
    
    @MainActor
    private func showManageSubscriptions() async {
#if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        try? await AppStore.showManageSubscriptions(in: windowScene)
#else
        try? await AppStore.showManageSubscriptions()
#endif
    }
}

#Preview {
    let app = AppState()

    AboutView()
        .environment(app.storeManager)
}
