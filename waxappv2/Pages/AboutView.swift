//
//  AboutView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 07/01/2026.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        NavigationStack {
            List {
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
        }
    }
}

#Preview {
    AboutView()
        .environmentObject(WaxSelectionStore())
}
