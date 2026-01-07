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
    
    var body: some View {
            TabView(selection: $selectedTab) {
                Tab("Wax", systemImage: "snow", value: .waxes) {
                    MainView()
                }
                Tab("About", systemImage: "info.circle", value: .about) {
                    AboutView()
                }
            }
    }
}

#Preview {
    let app = AppState()
    ContentView()
        .environmentObject(app.location)
        .environmentObject(app.weather)
        .environmentObject(app.recommendation)
}
