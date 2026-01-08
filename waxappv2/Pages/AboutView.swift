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
    
    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    if storeManager.isPurchased {
                        Label("Premium Active", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Free Trial", systemImage: "clock")
                                Spacer()
                                if case .warning(let days) = storeManager.trialStatus {
                                    Text("\(days) days left")
                                        .foregroundStyle(.red)
                                } else if storeManager.trialStatus == .expired {
                                    Text("Expired")
                                        .foregroundStyle(.red)
                                } else {
                                    Text("Active")
                                        .foregroundStyle(.green)
                                }
                            }
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
                    Link(destination: URL(string: "https://squarewave.no/terms")!) {
                        Text("Terms of Service")
                    }
                    Link(destination: URL(string: "https://squarewave.no/privacy")!) {
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
    AboutView()
        .environmentObject(WaxSelectionStore())
}
