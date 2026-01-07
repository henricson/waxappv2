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
                    WaxRecommendView()
                }
                Tab("About", systemImage: "gear", value: .about) {
                    AboutView()
                }
            }
    }
}

#Preview {
    @Previewable @StateObject var locationManager = LocationManager()
        ContentView()
            .environmentObject(locationManager)
    
}
