//
//  waxappv2App.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI

@main
struct waxappv2App: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState.location)
                .environmentObject(appState.weather)
                .environmentObject(appState.waxSelection)
                .environmentObject(appState.recommendation)
                .environmentObject(appState.storeManager)
        }
    }
}
