//
//  MainView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import CoreLocation
import TipKit
import Observation

// MARK: - TipKit

struct GanttScrollTip: Tip {
    var title: Text {
        Text("Adjust Temperature", comment: "Tip title for Gantt scroll")
    }
    
    var message: Text? {
        Text("Scroll horizontally to adjust the temperature and see different wax recommendations.", comment: "Tip message for Gantt scroll")
    }
    
    var image: Image? {
        Image(systemName: "hand.draw")
    }
}

struct MainView: View {
    @Environment(RecommendationStore.self) private var recStore
    @Environment(LocationStore.self) private var locStore
    @Environment(WeatherStore.self) private var weatherStore
    @Environment(WaxSelectionStore.self) private var waxStore
    @Environment(StoreManager.self) private var storeManager

    @Environment(\.colorScheme) var colorScheme: ColorScheme
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    // UI State
    @State private var showMapSelection = false
    @State private var showLocationPermissionAlert = false
    @State private var showLocationTimeoutAlert = false
    @State private var showWeatherErrorAlert = false
    @State private var locationTimeoutTask: Task<Void, Never>?
    @State private var weatherErrorMessage: String = ""
    @State private var lastWeatherStatus: WeatherStore.Status?
    @State private var showPaywall = false
    @State private var pendingPostAuthReset = false
    
    // TipKit
    private let scrollTip = GanttScrollTip()
    
    // MARK: - Computed Properties
    
    private var remainingTrialDays: Int {
        if case .warning(let days) = storeManager.trialStatus {
            return days
        } else if case .active = storeManager.trialStatus {
            let daysSinceStart = storeManager.daysSinceStart
            return max(0, 14 - daysSinceStart)
        }
        return 0
    }
    
    private var shouldShowPurchaseButton: Bool {
        !storeManager.isPurchased && storeManager.trialStatus != .expired
    }

    // MARK: - View Components

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
                                recStore.setTemperature(target)
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
                    set: { recStore.setSnowType($0) }
                )
            )
            .frame(height: 44)
            
            LocationSourceIndicator(
                isManualOverride: locStore.locationStatus == .manual_override,
                isUsingWeatherData: recStore.isUsingWeatherTemperature && recStore.isUsingWeatherSnowType
            )
            
            if recStore.isUsingWeatherSnowType, let assessment = weatherStore.currentAssessment {
                SnowAssessmentSummaryView(assessment: assessment)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 2)
                    .padding(.horizontal, 10)
            }
        }
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.3), value: recStore.isUsingWeatherTemperature && recStore.isUsingWeatherSnowType)
    }

    private var ganttSection: some View {
        Gantt(
            temperature: Binding(
                get: { recStore.temperature },
                set: { recStore.setTemperature($0) }
            ),
            snowType: Binding(
                get: { recStore.snowType },
                set: { recStore.setSnowType($0) }
            ),
            selectedWaxes: swixWaxes.filter { waxStore.selectedWaxIDs.contains($0.id) }
        )
        .overlay(alignment: .top) {
            TipView(scrollTip, arrowEdge: .top)
                .padding(.horizontal)
                .padding(.top, 70)
        }
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
                    headerSection
                    
                    snowTypeSection
                    
                    ganttSection
                        .frame(minHeight: geometry.size.height - 300)
                }
                .animation(.easeInOut(duration: 0.3), value: recStore.isUsingWeatherTemperature && recStore.isUsingWeatherSnowType)
            }
            .background(backgroundView)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        let isLocationLoading = locStore.locationStatus == .searching
        let isWeatherLoading = weatherStore.status == .loading
        let isAnyLoading = isLocationLoading || isWeatherLoading
        
        let shouldHighlightMap = locStore.locationStatus == .manual_override && !recStore.isOverridden
        let shouldHighlightLocation = locStore.locationStatus == .active && !recStore.isOverridden
        
        let mapTint: Color? = shouldHighlightMap ? .blue : nil
        let locationTint: Color? = shouldHighlightLocation ? .blue : nil

        ToolbarItem(placement: .topBarLeading) {
            Button {
                showMapSelection = true
            } label: {
                ZStack {
                    Image(systemName: "map")
                    
                    if isWeatherLoading && locStore.locationStatus == .manual_override {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .toolbarButtonStyle(tint: mapTint)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                handleReset()
            } label: {
                if locStore.authorizationStatus == .denied {
                    Image(systemName: "location.slash")
                } else if isAnyLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: recStore.isOverridden ? "location.slash.fill" : "location.fill")
                }
            }
            .toolbarButtonStyle(tint: locationTint)
    
        }
    }

    // MARK: - Alert Actions

    @ViewBuilder
    private var locationPermissionAlertActions: some View {
        Button("Cancel", role: .cancel) { }
        Button("Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    @ViewBuilder
    private var locationTimeoutAlertActions: some View {
        Button("Retry") {
            locStore.requestLocation()
            startLocationTimeout()
        }
        Button("Select Manually") {
            showMapSelection = true
        }
        Button("Cancel", role: .cancel) { }
    }

    @ViewBuilder
    private var weatherErrorAlertActions: some View {
        Button("Set Manually") {
            showWeatherErrorAlert = false
        }
        Button("Retry") {
            if locStore.location != nil {
                Task {
                    await weatherStore.refresh()
                }
            }
        }
        Button("Cancel", role: .cancel) { }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mainContent
                
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
            .sheet(isPresented: $showMapSelection) {
                MapSelectView()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("Location Permission Denied", isPresented: $showLocationPermissionAlert) {
                locationPermissionAlertActions
            } message: {
                Text("Please enable location services in settings, or select your position manually using the top left map button.")
            }
            .alert("Location Timeout", isPresented: $showLocationTimeoutAlert) {
                locationTimeoutAlertActions
            } message: {
                Text("Unable to determine your location. Please check your connection and try again, or select your location manually.")
            }
            .alert("Weather Data Unavailable", isPresented: $showWeatherErrorAlert) {
                weatherErrorAlertActions
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
            .onChange(of: hasSeenOnboarding) { _, newValue in
                if newValue {
                    initializeLocation()
                }
            }
            .task(id: locStore.location) {
                if hasSeenOnboarding {
                    await weatherStore.fetchIfNeeded()
                }
            }
            .onAppear {
                if hasSeenOnboarding {
                    initializeLocation()
                }
            }
            .onDisappear {
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
        locationTimeoutTask?.cancel()
        
        locationTimeoutTask = Task {
            do {
                try await Task.sleep(for: .seconds(20))
                
                if locStore.locationStatus == .searching {
                    showLocationTimeoutAlert = true
                    locStore.locationStatus = .fault_searching
                }
            } catch {
                // Task was cancelled
            }
        }
    }
    
    private func handleLocationStatusChange(oldStatus: LocationStatus, newStatus: LocationStatus) {
        if newStatus == .searching {
            startLocationTimeout()
        }
        
        if newStatus == .active || newStatus == .manual_override {
            locationTimeoutTask?.cancel()
            locationTimeoutTask = nil
        }
        
        // Reset overrides when switching to manual location (from map)
        // so that weather data for the new location is applied
        if newStatus == .manual_override && oldStatus != .manual_override {
            recStore.resetOverrides()
        }
    }
    
    private func handleLocationAuthorizationStateChange(_ newStatus: CLAuthorizationStatus) {
        switch newStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Only proceed if onboarding is done, or if this is a direct follow-up
            // from the user's tap while asking for authorization.
            guard hasSeenOnboarding || pendingPostAuthReset else { return }

            if pendingPostAuthReset {
                pendingPostAuthReset = false
                // Clear manual override and reset recommendation overrides so new device location applies immediately
                locStore.clearManualLocation()
                recStore.resetOverrides()
            }

            // Immediately fetch location after permission is granted
            locStore.requestLocation()
        case .denied, .restricted:
            break
        case .notDetermined:
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

        if locStore.authorizationStatus == .authorizedAlways || locStore.authorizationStatus == .authorizedWhenInUse {
            locStore.requestLocation()
        }
    }

    private func handleReset() {
        guard hasSeenOnboarding else { return }
        switch locStore.authorizationStatus {
        case .denied, .restricted:
            showLocationPermissionAlert = true
        case .notDetermined:
            pendingPostAuthReset = true
            locStore.requestAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locStore.clearManualLocation()
            recStore.resetOverrides()
            locStore.requestLocation()
        @unknown default:
            break
        }
    }
}

// MARK: - View Extension

struct ToolbarButtonStyle: ButtonStyle {
    var tint: Color?
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint ?? .primary)
            .frame(width: 20, height: 20)
            .padding(10)
            .background(
                Circle()
                    .fill(.white)
            )
            .clipShape(Circle())
            .contentShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    @ViewBuilder
    func toolbarButtonStyle(tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint = tint {
                self.tint(tint)
            } else {
                self
            }
        } else if #available(iOS 18.0, *) {
            self.buttonStyle(ToolbarButtonStyle(tint: tint))  // Style only on iOS 18-25
        } else {
            self  // No styling on iOS 17 and earlier
        }
    }
}

// MARK: - Preview

#Preview {
    let app = AppState()
    MainView()
        .environment(app.location)
        .environment(app.weather)
        .environment(app.recommendation)
        .environment(app.waxSelection)
        .environment(app.storeManager)
}

