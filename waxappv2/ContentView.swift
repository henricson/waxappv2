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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WaxCanGraphic(
                        bodyFill: LinearGradient(colors: [.blue, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                        
                    )
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
                    
                    // Location control (one-shot)
                    HStack(spacing: 12) {
                        Button {
                            locationManager.fetchLocationOnce()
                        } label: {
                            Label("Get Location", systemImage: "location")
                        }
                        .buttonStyle(.bordered)
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
                .onChange(of: locationManager.authorizationStatus) { _, _ in
                    // Ensure auth flow is applied if needed
                    locationManager.requestAuthorizationIfNeeded()
                }
                .onChange(of: locationManager.lastLocation) { _, newLoc in
                    // Automatically fetch forecast whenever a new location is available
                    guard let loc = newLoc else { return }
                    Task { await viewModel.fetch(for: loc) }
                }
                .onAppear {
                    // Ensure auth flow is initiated if needed
                    locationManager.requestAuthorizationIfNeeded()
                    // If a location is already available on appear, fetch immediately
                    if let loc = locationManager.lastLocation {
                        Task { await viewModel.fetch(for: loc) }
                    }
                }
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
                //locationManager.openAppSettings()
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
}

#Preview {
    ContentView()
        .environmentObject(LocationManager())
}
