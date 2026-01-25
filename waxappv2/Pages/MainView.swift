//
//  MainView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import CoreLocation
import TipKit
import Combine

struct MainView: View {
    @EnvironmentObject var recStore: RecommendationStore
    @EnvironmentObject var locStore: LocationStore
    @EnvironmentObject var weatherStore: WeatherStore
    @EnvironmentObject var waxStore: WaxSelectionStore
    @EnvironmentObject var storeManager: StoreManager

    @Environment(\.colorScheme) var colorScheme: ColorScheme

    // UI State
    @State private var showMapSelection = false
    @State private var showLocationPermissionAlert = false
    @State private var showLocationTimeoutAlert = false
    @State private var showWeatherErrorAlert = false
    @State private var locationTimeoutTask: Task<Void, Never>?
    @State private var weatherErrorMessage: String = ""
    @State private var lastWeatherStatus: WeatherStore.Status?
    @State private var showPaywall = false
    
    private var remainingTrialDays: Int {
        if case .warning(let days) = storeManager.trialStatus {
            return days
        } else if case .active = storeManager.trialStatus {
            // Calculate actual remaining days for active trial
            let daysSinceStart = storeManager.daysSinceStart
            return max(0, 14 - daysSinceStart)
        }
        return 0
    }
    
    private var shouldShowPurchaseButton: Bool {
        !storeManager.isPurchased && storeManager.trialStatus != .expired
    }

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
        VStack(spacing: 12) {
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
            .frame(height: 44) // Give explicit height for the buttons
            
            LocationSourceIndicator(
                isManualOverride: locStore.locationStatus == .manual_override,
                isUsingWeatherData: recStore.isUsingWeatherTemperature && recStore.isUsingWeatherSnowType
            )
        }
        .padding(.vertical, 12)
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
                        .frame(minHeight: geometry.size.height - 300) // Fill to tab bar: total height - header (200) - snow type section (~80)
                }
                .animation(.easeInOut(duration: 0.3), value: recStore.isUsingWeatherTemperature && recStore.isUsingWeatherSnowType)
            }
            .background(backgroundView)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        // MARK: - Loading States
        let isLocationLoading = locStore.locationStatus == .searching
        let isWeatherLoading = weatherStore.status == .loading
        let isAnyLoading = isLocationLoading || isWeatherLoading
        
        // MARK: - Location-source tinting
        // Map button: blue when manual override AND no user temperature/snow type overrides
        let shouldHighlightMap = locStore.locationStatus == .manual_override && !recStore.isOverridden
        
        // Location button: blue when using GPS location AND no user temperature/snow type overrides
        let shouldHighlightLocation = locStore.locationStatus == .active && !recStore.isOverridden
        
        let highlightColor: Color = .blue
        let mapTint: Color? = shouldHighlightMap ? highlightColor : nil
        let locationTint: Color? = shouldHighlightLocation ? highlightColor : nil

        // MARK: - Left: Map Selection
        ToolbarItem(placement: .topBarLeading) {
            Button("Map", systemImage: "map") {
                showMapSelection = true
            }
            .tint(mapTint)
            .overlay(alignment: .center) {
                if isWeatherLoading && locStore.locationStatus == .manual_override {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.primary)
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                handleReset()
            } label: {
                if locStore.authorizationStatus == .denied {
                    Image(systemName: "location.slash")
                } else {
                    if isAnyLoading {
                        ProgressView()
                            .controlSize(.small)
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
            ZStack(alignment: .bottom) {
                mainContent
                
                // Floating purchase button
                if shouldShowPurchaseButton {
                    FloatingPurchaseButton(remainingDays: remainingTrialDays) {
                        showPaywall = true
                    }
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle(locStore.location?.placeName ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { mainToolbar }
            // MARK: - Modals & Alerts
            .sheet(isPresented: $showMapSelection) {
                MapSelectView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
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
                .alert("Location Timeout", isPresented: $showLocationTimeoutAlert) {
                    Button("Retry") {
                        locStore.requestLocation()
                        startLocationTimeout()
                    }
                    Button("Select Manually") {
                        showMapSelection = true
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Unable to determine your location. Please check your connection and try again, or select your location manually.")
                }
                .alert("Weather Data Unavailable", isPresented: $showWeatherErrorAlert) {
                    Button("Set Manually") {
                        // User can manually adjust temperature and snow type
                        showWeatherErrorAlert = false
                    }
                    Button("Retry") {
                        if let location = locStore.location {
                            Task {
                                await weatherStore.refresh(location: location)
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Unable to fetch weather data. \(weatherErrorMessage)\n\nYou can set the temperature and snow type manually using the controls below.")
                }
                .onChange(of: locStore.authorizationStatus) { _, newStatus in
                    handleLocationAuthorizationStateChange(newStatus)
                }
                .onChange(of: locStore.locationStatus) { oldStatus, newStatus in
                    handleLocationStatusChange(oldStatus: oldStatus, newStatus: newStatus)
                }
                .onChange(of: weatherStore.status) { _, newStatus in
                    handleWeatherStatusChange(newStatus)
                }
                .task {
                    // Continuously monitor weather status
                    for await status in weatherStore.$status.values {
                        if case .failed(let errorMessage) = status {
                            weatherErrorMessage = errorMessage
                            showWeatherErrorAlert = true
                        }
                    }
                }
                .onAppear {
                    initializeLocation()
                }
                .onDisappear {
                    // Cancel timeout task when view disappears
                    locationTimeoutTask?.cancel()
                    locationTimeoutTask = nil
                }
        }
    }

    // MARK: - Helper Methods
    
    private func handleWeatherStatusChange(_ status: WeatherStore.Status) {
        print("🌤️ Weather status changed to: \(status)")
        switch status {
        case .failed(let errorMessage):
            print("❌ Weather error: \(errorMessage)")
            weatherErrorMessage = errorMessage
            showWeatherErrorAlert = true
        default:
            break
        }
    }
    
    private func startLocationTimeout() {
        // Cancel any existing timeout task
        locationTimeoutTask?.cancel()
        
        locationTimeoutTask = Task {
            do {
                try await Task.sleep(for: .seconds(20))
                
                // If still searching after 20 seconds, show alert
                if locStore.locationStatus == .searching {
                    showLocationTimeoutAlert = true
                    locStore.locationStatus = .fault_searching
                }
            } catch {
                // Task was cancelled, do nothing
            }
        }
    }
    
    private func handleLocationStatusChange(oldStatus: LocationStatus, newStatus: LocationStatus) {
        // If we transition to searching, start the timeout
        if newStatus == .searching {
            startLocationTimeout()
        }
        
        // If we successfully get a location or override, cancel the timeout
        if newStatus == .active || newStatus == .manual_override {
            locationTimeoutTask?.cancel()
            locationTimeoutTask = nil
        }
    }
    
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
