//
//  waxappv2App.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI

@main
struct waxappv2App: App {
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .task {
                    // At launch: attempt one-shot fetch.
                    // - If authorized: performs requestLocation()
                    // - If notDetermined: shows prompt and auto-fetches once after grant
                    // - If denied/restricted: shows message; user can open Settings from UI
                    await MainActor.run {
                        locationManager.fetchLocationOnce(autoRequestPermission: true)
                    }
                }
        }
    }
}
