//
//  ContentView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel = WeatherViewModel()

    // User preference: auto-update location continuously
    @AppStorage("autoUpdateLocation") private var autoUpdateLocation: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                headerSection

                // Location status and controls
                Group {
                    switch locationManager.authorizationStatus {
                    case .authorizedAlways, .authorizedWhenInUse:
                        authorizedSection
                    case .notDetermined:
                        Text("Requesting permission…")
                            .foregroundStyle(.secondary)
                    case .denied, .restricted:
                        deniedSection
                    @unknown default:
                        Text("Unknown authorization state")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = locationManager.errorDescription, !error.isEmpty {
                    Text(error).foregroundColor(.red)
                }

                Divider()

                // Weather fetch controls
                HStack(spacing: 12) {
                    Button {
                        locationManager.fetchLocationOnce()
                    } label: {
                        Label("Get Location", systemImage: "location")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            if let loc = locationManager.lastLocation {
                                await viewModel.fetch(for: loc)
                            }
                        }
                    } label: {
                        Label("Fetch Forecast", systemImage: "cloud.sun")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(locationManager.lastLocation == nil)
                }

                if viewModel.isLoading {
                    ProgressView("Fetching weather…")
                }

                if let err = viewModel.errorMessage {
                    Text(err).foregroundStyle(.red)
                }

                // Results
                resultsSection
            }
            .padding()
            .navigationTitle("Snow surface")
            .onChange(of: autoUpdateLocation) { _, newValue in
                handleAutoUpdateToggle(newValue)
            }
            .onChange(of: locationManager.authorizationStatus) { _, _ in
                // Apply current auto-update preference when auth changes
                handleAutoUpdateToggle(autoUpdateLocation)
            }
            .onChange(of: locationManager.lastLocation) { _, newLoc in
                // When auto-update is ON, fetch automatically on new location
                guard autoUpdateLocation, let loc = newLoc else { return }
                Task { await viewModel.fetch(for: loc) }
            }
            .onAppear {
                // Ensure auth flow is initiated if needed
                locationManager.requestAuthorizationIfNeeded()
                // Apply auto-update setting on appear
                handleAutoUpdateToggle(autoUpdateLocation)
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Image(systemName: "snowflake")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Determine likely snow type for current conditions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var authorizedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $autoUpdateLocation) {
                Label("Auto-update location", systemImage: "location.circle")
            }

            if let loc = locationManager.lastLocation {
                Text(String(format: "Lat: %.4f, Lon: %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Waiting for location…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .task {
                        // If we’re authorized but don’t have a fix yet, trigger a one-shot fetch.
                        locationManager.fetchLocationOnce(autoRequestPermission: false)
                    }
            }
        }
    }

    private var deniedSection: some View {
        VStack(spacing: 8) {
            Text("Location permission is not granted.")
            Button("Open Settings") {
                locationManager.openAppSettings()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let current = viewModel.currentAssessment {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current assessment")
                            .font(.headline)
                        Text("\(current.group.titleNo)")
                            .font(.title2)
                        if !current.reasons.isEmpty {
                            ForEach(current.reasons, id: \.self) { reason in
                                Label(reason, systemImage: "info.circle")
                                    .font(.callout)
                            }
                        }
                        if let hours = current.hoursAboveZero {
                            Text("Hours above 0 °C soon: \(hours)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No current assessment yet. Fetch a forecast.")
                    .foregroundStyle(.secondary)
            }

            if !viewModel.pastDailyAssessments.isEmpty {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent days")
                            .font(.headline)
                        ForEach(viewModel.pastDailyAssessments) { assess in
                            HStack {
                                Text(assess.date, style: .date)
                                Spacer()
                                Text(assess.group.titleNo)
                            }
                            .font(.callout)
                            .accessibilityLabel("\(assess.date.formatted(date: .abbreviated, time: .omitted)), \(assess.group.titleNo)")
                        }
                    }
                }
            }
        }
    }

    private func handleAutoUpdateToggle(_ enabled: Bool) {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if enabled {
                locationManager.startUpdating()
            } else {
                locationManager.stopUpdating()
            }
        default:
            break
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
}
