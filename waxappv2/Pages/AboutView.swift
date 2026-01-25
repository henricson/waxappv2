//
//  AboutView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 07/01/2026.
//

import SwiftUI

struct AboutView: View {
    @EnvironmentObject var storeManager: StoreManager
    @State private var showPaywall = false

    private var daysLeftInTrial: Int {
        max(0, 14 - storeManager.daysSinceStart)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Purchase status") {
                    if storeManager.isPurchased {
                        Label("App purchased", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        // Trial status summary
                        Group {
                            Label("Free Trial", systemImage: "clock")

                            if storeManager.trialStatus == .expired {
                                Text("Expired")
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                            } else {
                                Text("\(daysLeftInTrial) days left in trial")
                                    .font(.subheadline)
                                    .foregroundStyle(daysLeftInTrial <= 4 ? .red : .green)
                                    .accessibilityLabel("\(daysLeftInTrial) days left in trial")
                            }
                        }

                        Button {
                            showPaywall = true
                        } label: {
                            Label("Purchase the app", systemImage: "arrow.up.circle")
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
                    Link(destination: URL(string: "https://squarewave.no")!) {
                        Label("Square Wave AS", systemImage: "link")
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
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

#Preview {
    let app = AppState()

    AboutView()
        .environmentObject(app.location)
        .environmentObject(app.weather)
        .environmentObject(app.waxSelection)
        .environmentObject(app.recommendation)
        .environmentObject(app.storeManager)
}
