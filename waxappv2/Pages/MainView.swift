//
//  MainView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import CoreLocation
import TipKit

struct MainView: View {
    @EnvironmentObject var recStore: RecommendationStore
    @EnvironmentObject var locStore: LocationStore
    @EnvironmentObject var weatherStore: WeatherStore
    @EnvironmentObject var waxStore: WaxSelectionStore

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    // UI State
    @State private var showMapSelection = false
    @State private var showLocationPermissionAlert = false

    private var headerSection: some View {
        Group {
            if let recommended = recStore.recommended.first {
                HeaderCanView(recommendedWax: recommended.wax)
                    .id(recommended.wax.id)
            } else {
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "info.triangle")
                        Text("Outside of range")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                    }
                    if let target = recStore.nearestRecommendedTemperature(from: recStore.temperature) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                recStore.temperature = target
                            }
                        } label: {
                            Label(
                                "Move back",
                                systemImage: target > recStore.temperature ? "arrow.right" : "arrow.left"
                            )
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .accessibilityHint("Scrolls the temperature scale to the nearest range with recommendations")
                    }
                }
            }
        }
        .frame(height: 200)
    }

    private var snowTypeSection: some View {
        VStack(spacing: 8) {

            SnowTypeButtons(
                selected: Binding(
                    get: { recStore.snowType },
                    set: { newValue in
                        // If the user taps the same as weather, maybe clear override?
                        // For now, just set the override.
                        recStore.userSelectedSnowType = newValue
                    }
                )
            )

            LocationSourceIndicator(
                isManualOverride: locStore.locationStatus == .manual_override,
                isUsingWeatherData: recStore.isUsingWeatherTemperature && recStore.isUsingWeatherSnowType
            )
        }
        .animation(.easeInOut(duration: 0.3), value: recStore.isUsingWeatherTemperature && recStore.isUsingWeatherSnowType)
    }

    private var ganttSection: some View {
        Gantt(temperature: $recStore.temperature, snowType: $recStore.snowType, selectedWaxes: swixWaxes.filter { waxStore.selectedWaxIDs.contains($0.id)})
    }

    private var backgroundView: some View {
        ZStack {
            Color.clear.ignoresSafeArea(edges: .top)
            if let recommended = recStore.recommended.first {
                LinearGradient(
                    colors: [Color(hex: recommended.wax.backgroundColor) ?? .blue, colorScheme == .dark ? .black : .white],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
                .transition(.opacity)
                .id(recommended.wax.primaryColor)
            }
        }
        .animation(.easeIn, value: recStore.recommended.first?.wax.primaryColor)
    }

    private var mainContent: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    headerSection // 200pt
                    
                    snowTypeSection

                        .frame(height: 100)

                    // ~64pt
                    
                    ganttSection
                        .frame(minHeight: geometry.size.height - 300) // Fill to tab bar: total height - header (200) - snow type section (~92)
                }
                .animation(.easeInOut(duration: 0.3), value: recStore.isUsingWeatherTemperature && recStore.isUsingWeatherSnowType)
            }
            .background(backgroundView)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        // MARK: - Location-source tinting
        // Highlight map button only if using manual location AND both temp and snow type are from weather
        let shouldHighlightMap = locStore.locationStatus == .manual_override
        
        // Highlight location button only if NOT using manual location AND both temp and snow type are from weather
        let shouldHighlightLocation = locStore.locationStatus == .active
        
        let highlightColor: Color = .blue
        let mapTint: Color? = shouldHighlightMap ? highlightColor : nil
        let locationTint: Color? = shouldHighlightLocation ? highlightColor : nil

        // MARK: - Left: Map Selection
        ToolbarItem(placement: .topBarLeading) {
            Button("Map", systemImage: "map") {
                showMapSelection = true
            }
            .tint(mapTint)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                handleReset()
            } label: {
                if locStore.authorizationStatus == .denied {
                    Image(systemName: "location.slash")
                } else {
                    if locStore.locationStatus == .searching {
                        Image(systemName: "progress.indicator")
                    } else {
                        Image(systemName: recStore.isOverridden ? "location.slash.fill" : "location.fill")
                    }
                }
            }
            .tint(locationTint)
        }
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(locStore.location?.placeName ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { mainToolbar }
                // MARK: - Modals & Alerts
                .sheet(isPresented: $showMapSelection) {
                    MapSelectView()
                }
                .alert("Location Permission Denied", isPresented: $showLocationPermissionAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                } message: {
                    Text("Please enable location services in settings, or select your position manually using the top left map button.")
                }
                .onChange(of: locStore.authorizationStatus) { _, newStatus in
                    handleLocationAuthorizationStateChange(newStatus)
                }
                .onAppear {
                    initializeLocation()
                }
        }
    }

    // MARK: - Helper Methods
    
    private func handleLocationAuthorizationStateChange(_ newStatus : CLAuthorizationStatus) {
        switch newStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Once the user grants permission, immediately fetch a location so WeatherStore can update.
            locStore.requestLocation()
        case .denied, .restricted:
            // Allow the user to opt into showing the alert via the location button.
            break
        case .notDetermined:
            // Keep waiting for the user to answer the system prompt.
            break
        @unknown default:
            break
        }
    }
    
    private func initializeLocation() {
        if locStore.authorizationStatus == .notDetermined {
            locStore.requestAuthorization()
            return
        }

        // Only request a location if we're already authorized.
        if locStore.authorizationStatus == .authorizedAlways || locStore.authorizationStatus == .authorizedWhenInUse {
            locStore.requestLocation()
        }
    }

    private func handleReset() {
        switch locStore.authorizationStatus {
        case .denied, .restricted:
            showLocationPermissionAlert = true
        case .notDetermined:
            locStore.requestAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            // 1. Clear any manual map selection
            locStore.clearManualLocation()
            // 2. Clear overrides (snow type & temp)
            recStore.resetOverrides()
            // 3. Force a refresh of GPS
            locStore.requestLocation()
        @unknown default:
            break
        }
    }
}

#Preview {
    let app = AppState()
    MainView()
        .environmentObject(app.location)
        .environmentObject(app.weather)
        .environmentObject(app.recommendation)
        .environmentObject(app.waxSelection)
    
}
