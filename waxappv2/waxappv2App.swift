//
//  waxappv2App.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import Observation
import TipKit

@main
struct waxappv2App: App {
    @State private var appState = AppState()

    init() {
        // Configure TipKit
        #if DEBUG
        try? Tips.resetDatastore()
        #endif
        try? Tips.configure([
            .displayFrequency(.immediate),
            .datastoreLocation(.applicationDefault)
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState.location)
                .environment(appState.weather)
                .environment(appState.waxSelection)
                .environment(appState.recommendation)
                .environment(appState.storeManager)
        }
    }
}
