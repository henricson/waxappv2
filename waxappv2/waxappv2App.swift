//
//  waxappv2App.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import Observation

@main
struct waxappv2App: App {
    @State private var appState = AppState()

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
