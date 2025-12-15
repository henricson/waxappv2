//
//  LocationButton.swift
//  waxappv2
//
//  Created by Herman Henriksen on 19/10/2025.
//

import SwiftUI
import CoreLocation
import UIKit

struct LocationButton: View {

    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showDeniedAlert: Bool = false

    private var hasEffectiveLocation: Bool {
        locationManager.effectiveLocation != nil
    }

    private var isDenied: Bool {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    private var isAuthorized: Bool {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    private var isNotDetermined: Bool {
        locationManager.authorizationStatus == .notDetermined
    }

    // Only show place name; never coordinates
    private var titleText: String {
        if let name = locationManager.placeName, !name.isEmpty {
            return name
        } else {
            return "Fetch location"
        }
    }

    var body: some View {
        Button("Get location", systemImage: "location") {
            // TODO: - Do something
            handleTap()
        }
        .accessibilityLabel("Get Location")
        .alert("Location Permission Denied", isPresented: $showDeniedAlert) {
            Button("Open Settings") { openAppSettings() }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Location permission is denied or restricted. Enable it in Settings to fetch your location.")
        }
    }

    // MARK: - Actions

    private func handleTap() {
        if isDenied {
            // Show alert if denied or restricted
            showDeniedAlert = true
            return
        }
        if isNotDetermined {
            // Ask for permission; your manager will prompt
            locationManager.fetchLocationOnce(autoRequestPermission: true)
            return
        }
        if isAuthorized {
            // Fetch immediately
            locationManager.fetchLocationOnce(autoRequestPermission: false)
            return
        }
        // Fallback
        locationManager.fetchLocationOnce()
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    Group {
        LocationButton()
            .environmentObject(LocationManager())
            .preferredColorScheme(.light)
            .padding()
    }
}
