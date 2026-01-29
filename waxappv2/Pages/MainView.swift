//
//  MainView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import TipKit
import Observation
import CoreLocation
import WeatherKit

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
    @State private var showPaywall = false
    @State private var pendingPostAuthReset = false
    @State private var showSnowAssessmentExplain = false

    // TipKit
    private let scrollTip = GanttScrollTip()

    @State private var isUserInitiatedLocationRequest = false

    /// Minimal extra scroll space so the attribution/footer can be scrolled above the floating purchase button.
    private var scrollBottomPadding: CGFloat {
        // FloatingPurchaseButton is ~56pt tall, plus the 8pt bottom padding applied in the safeAreaInset.
        // Add a small buffer so the last line doesn’t visually collide with the button.
        shouldShowPurchaseButton ? (56 + 10 + 6) : 0
    }

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

    /// A small, conservative min-height that helps the Gantt resize smoothly when bottom UI appears/disappears.
    /// (MainView is scrollable now, so we don't need to force a min-height here.)
    // private var ganttMinHeight: CGFloat { ... }

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
                    if let target = recStore.nearestRecommendedTemperature(from: recStore.effectiveTemperature) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                recStore.effectiveTemperature = target
                            }
                        } label: {
                            Label(
                                "Move back",
                                systemImage: target > recStore.effectiveTemperature ? "arrow.right" : "arrow.left"
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
                store: recStore
            )
            .frame(height: 44)
            
            LocationSourceIndicator(
                isManualOverride: locStore.locationStatus == .manual_override,
                isUsingWeatherData: recStore.isSameAsWeatherKit
            )
            
        }
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.3), value: recStore.isSameAsWeatherKit)
    }

    private var ganttSection: some View {
        Gantt(
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
        ZStack {
            backgroundView

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    headerSection
                        .frame(height: 200)

                    snowTypeSection

                    ganttSection
                        .frame(maxWidth: .infinity)

                    if recStore.isSameAsWeatherKit {
                        WeatherAttributionView()
                            .padding(.top, 20)
                            .padding(.bottom, 16)
                            .frame(maxWidth: .infinity)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Only enough spacing to allow scrolling the footer above the floating purchase button.
                    Color.clear
                        .frame(height: scrollBottomPadding)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .overlay(alignment: .bottom) {
            if shouldShowPurchaseButton {
                FloatingPurchaseButton(remainingDays: remainingTrialDays) {
                    showPaywall = true
                }
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: recStore.isSameAsWeatherKit)
        .animation(.easeInOut(duration: 0.35), value: shouldShowPurchaseButton)
    }

    @ViewBuilder
    private func contentStack(ganttHeight: CGFloat) -> some View {
        // (No longer used; keeping this signature around caused the old GeometryReader height forcing.)
        EmptyView()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {

        ToolbarItem(placement: .topBarLeading) {
            Button {
                showMapSelection = true
            } label: {
                Image(systemName: "map")
            }
            .toolbarButtonStyle(tint: locStore.locationStatus == .manual_override && recStore.isSameAsWeatherKit ? .accentColor : .primary)
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                // Check if already denied/restricted before requesting
                switch locStore.authorizationStatus {
                case .denied, .restricted:
                    showLocationPermissionAlert = true
                case .notDetermined:
                    isUserInitiatedLocationRequest = true
                    locStore.requestAuthorization()
                case .authorizedWhenInUse, .authorizedAlways:
                    isUserInitiatedLocationRequest = true
                    locStore.requestLocation()
                @unknown default:
                    break
                }
            } label: {
                Image(systemName: "location.fill")
            }
            .toolbarButtonStyle(tint: recStore.isSameAsWeatherKit && locStore.locationStatus != .manual_override ? .accentColor : .primary)
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
            // startLocationTimeout()
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
                    await weatherStore.fetchWeather()
                }
            }
        }
        Button("Cancel", role: .cancel) { }
    }

    // MARK: - Body
    
    var body: some View {
            NavigationStack {
                mainContent
                    .navigationTitle(locStore.location?.placeName ?? "")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { mainToolbar }
                    .sheet(isPresented: $showMapSelection) {
                        MapSelectView()
                    }
                    .sheet(isPresented: $showPaywall) {
                        PaywallView()
                    }
                    .onChange(of: locStore.authorizationStatus) { _, newStatus in
                        // Only show alert for user-initiated requests
                        guard isUserInitiatedLocationRequest else { return }
                        
                        if newStatus == .denied || newStatus == .restricted {
                            showLocationPermissionAlert = true
                            isUserInitiatedLocationRequest = false
                        }
                    }
                    .onChange(of: locStore.locationStatus) { _, newStatus in
                        // Only show alert for user-initiated requests
                        guard isUserInitiatedLocationRequest else { return }
                        
                        switch newStatus {
                        case .fault_searching:
                            showLocationTimeoutAlert = true
                            isUserInitiatedLocationRequest = false
                        case .active:
                            // Successfully got location, reset flag
                            isUserInitiatedLocationRequest = false
                        default:
                            break
                        }
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
            }
        }

}

// MARK: - View Extension

struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherAttribution?
    @State private var didLoadAttribution = false
    
    private var logoURL: URL? {
        guard let attribution else { return nil }
        return colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
    }
    
    var body: some View {
        ZStack {
            if didLoadAttribution, let attribution {
                VStack(spacing: 6) {
                    // Apple Weather logo/trademark
                    if let logoURL {
                        AsyncImage(url: logoURL) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(height: 16)
                        } placeholder: {
                            appleWeatherText
                        }
                    } else {
                        appleWeatherText
                    }
                    
                    // Modification notice (required for value-added services)
                    Text("Data has been modified")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Link to data sources (required)
                    Link(destination: attribution.legalPageURL) {
                        HStack(spacing: 4) {
                            Text("Other Data Sources")
                                .font(.caption)
                            Image(systemName: "arrow.up.right.square")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                // Loading state
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity)
            }
        }
        // Keep the footer from jumping in height when content loads.
        .frame(minHeight: 44)
        .task {
            guard !didLoadAttribution else { return }
            let fetched = try? await WeatherService.shared.attribution
            withAnimation(.easeInOut(duration: 0.35)) {
                attribution = fetched
                didLoadAttribution = fetched != nil
            }
        }
    }
    
    private var appleWeatherText: some View {
        HStack(spacing: 4) {
            Image(systemName: "apple.logo")
                .font(.caption)
            Text("Weather")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
    }
}

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