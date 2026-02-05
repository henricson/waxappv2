//
//  MainView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import TipKit
import CoreLocation
import WeatherKit

#if canImport(UIKit)
import UIKit
#endif

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

// MARK: - Layout Constants

private enum LayoutConstants {
    static let headerHeight: CGFloat = 200
    static let snowTypeSectionHeight: CGFloat = 68
    static let attributionHeight: CGFloat = 100
    static let floatingButtonHeight: CGFloat = 74
    static let minimumGanttHeight: CGFloat = 200
}

// MARK: - MainView

struct MainView: View {
    @Environment(RecommendationStore.self) private var recStore
    @Environment(LocationStore.self) private var locStore
    @Environment(WeatherStore.self) private var weatherStore
    @Environment(WaxSelectionStore.self) private var waxStore
    @Environment(StoreManager.self) private var storeManager
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    // MARK: UI State
    
    @State private var showMapSelection = false
    @State private var showLocationPermissionAlert = false

    @State private var showWeatherErrorAlert = false
    @State private var showPaywall = false
    @State private var weatherErrorMessage = ""
    @State private var isUserInitiatedLocationRequest = false

    private let scrollTip = GanttScrollTip()

    // MARK: Computed Properties

    private var shouldShowPurchaseButton: Bool {
        !storeManager.hasAccess
    }
    
    private var showAttribution: Bool {
        recStore.isSameAsWeatherKit
    }
    
    private var selectedWaxes: [SwixWax] {
        swixWaxes.filter { waxStore.selectedWaxIDs.contains($0.id) }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle(locStore.location?.placeName ?? "")
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar { toolbarContent }
                .sheet(isPresented: $showMapSelection) {
                    MapSelectView()
                }
                .sheet(isPresented: $showPaywall) {
                    PaywallView()
                }
                .onChange(of: locStore.authorizationStatus, handleAuthorizationChange)
                .onChange(of: locStore.locationStatus, handleLocationStatusChange)
                .alert("Location Permission Denied", isPresented: $showLocationPermissionAlert) {
                    locationPermissionAlertActions
                } message: {
                    Text("Please enable location services in settings, or select your position manually using the top left map button.")
                }

                .alert("Weather Data Unavailable", isPresented: $showWeatherErrorAlert) {
                    weatherErrorAlertActions
                } message: {
                    Text("Unable to fetch weather data. \(weatherErrorMessage)\n\nYou can set the temperature and snow type manually using the controls below.")
                }
        }
    }
}

// MARK: - Main Content

private extension MainView {
    var mainContent: some View {
        ZStack {
            backgroundGradient
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    headerSection
                    snowTypeSection
                    ganttSection.frame(minHeight: 150)
                    attributionSection
                }
            }
            
        }
        .safeAreaInset(edge: .bottom) {
            // Keep the floating button pinned above the Tab Bar / home indicator
            floatingPurchaseButton
                .padding(.horizontal)
                .padding(.bottom, 10)
                .zIndex(1)
        }
        .overlay(alignment: .top) {
            // Show the tip above all content (and above the floating button)
            TipView(scrollTip, arrowEdge: .top)
                .padding(.horizontal)
                .padding(.top, LayoutConstants.headerHeight + LayoutConstants.snowTypeSectionHeight + 24 + 70)
        }
        .animation(.easeInOut(duration: 0.35), value: showAttribution)
        .animation(.easeInOut(duration: 0.35), value: shouldShowPurchaseButton)
    }

}

// MARK: - View Components

private extension MainView {
    var backgroundGradient: some View {
        Group {
            if let recommended = recStore.recommended.first {
                LinearGradient(
                    colors: [
                        Color(hex: recommended.wax.backgroundColor) ?? .blue,
                        colorScheme == .dark ? .black : .white
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .top)
                .transition(.opacity)
                .id(recommended.wax.primaryColor)
            } else {
                Color.clear.ignoresSafeArea(edges: .top)
            }
        }
        .animation(.easeIn, value: recStore.recommended.first?.wax.primaryColor)
    }

    var headerSection: some View {
        Group {
            if let recommended = recStore.recommended.first {
                HeaderCanView(recommendedWax: recommended.wax)
                    .id(recommended.wax.id)
            } else {
                outOfRangeHeader
            }
        }
        .frame(height: LayoutConstants.headerHeight)
    }
    
    var outOfRangeHeader: some View {
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

    var snowTypeSection: some View {
        VStack(spacing: 12) {
            SnowTypeButtons(store: recStore)
                .frame(height: 44)
            
            LocationSourceIndicator(
                isManualOverride: locStore.locationStatus == .manual_override,
                isUsingWeatherData: recStore.isSameAsWeatherKit
            )
        }
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.3), value: recStore.isSameAsWeatherKit)
    }

    var ganttSection: some View {
        Gantt(selectedWaxes: selectedWaxes)
    }
    
    @ViewBuilder
    var attributionSection: some View {
        if showAttribution {
            WeatherAttributionView()
                .padding(.top, 20)
                .frame(maxWidth: .infinity)
                .frame(height: LayoutConstants.attributionHeight)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    var floatingPurchaseButton: some View {
        if shouldShowPurchaseButton {
            FloatingPurchaseButton(
                subtitle: storeManager.isEligibleForIntroOffer ? "Start your 14-day free trial" : "Unlock full access",
                actionTitle: storeManager.isEligibleForIntroOffer ? "Start trial" : "Subscribe"
            ) {
                showPaywall = true
            }
            .padding(.bottom, 10)
        }
    }
}

// MARK: - Toolbar

private extension MainView {
    // Cross-platform toolbar placements
    var leadingToolbarPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .automatic
        #else
        return .topBarLeading
        #endif
    }

    var trailingToolbarPlacement: ToolbarItemPlacement {
        #if os(macOS)
        return .automatic
        #else
        return .topBarTrailing
        #endif
    }

    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: leadingToolbarPlacement) {
            Button {
                showMapSelection = true
            } label: {
                Image(systemName: "map")
            }
            .toolbarButtonStyle(
                tint: locStore.locationStatus == .manual_override && recStore.isSameAsWeatherKit ? .accentColor : .primary
            )
        }

        ToolbarItem(placement: trailingToolbarPlacement) {
            Button(action: handleLocationButtonTap) {
                Image(systemName: "location.fill")
            }
            .toolbarButtonStyle(
                tint: recStore.isSameAsWeatherKit && locStore.locationStatus != .manual_override ? .accentColor : .primary
            )
        }
    }
}

// MARK: - Actions & Handlers

private extension MainView {
    func handleLocationButtonTap() {
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
    }
    
    func handleAuthorizationChange(_ oldStatus: CLAuthorizationStatus, _ newStatus: CLAuthorizationStatus) {
        guard isUserInitiatedLocationRequest else { return }
        
        if newStatus == .denied || newStatus == .restricted {
            showLocationPermissionAlert = true
            isUserInitiatedLocationRequest = false
        }
    }
    
    func handleLocationStatusChange(_ oldStatus: LocationStatus, _ newStatus: LocationStatus) {
        guard isUserInitiatedLocationRequest else { return }
        
        switch newStatus {
        case .denied:
            showLocationPermissionAlert = true
            isUserInitiatedLocationRequest = false
        case .active:
            isUserInitiatedLocationRequest = false
        default:
            break
        }
    }
}

// MARK: - Alert Actions

private extension MainView {
    @ViewBuilder
    var locationPermissionAlertActions: some View {
        Button("Cancel", role: .cancel) { }
        #if canImport(UIKit)
        Button("Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        #endif
    }



    @ViewBuilder
    var weatherErrorAlertActions: some View {
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
}

// MARK: - WeatherAttributionView

struct WeatherAttributionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var attribution: WeatherAttribution?
    @State private var isLoaded = false
    
    private var logoURL: URL? {
        guard let attribution else { return nil }
        return colorScheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL
    }
    
    var body: some View {
        Group {
            if isLoaded, let attribution {
                attributionContent(attribution)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                ProgressView()
                    .controlSize(.small)
                    .transition(.opacity)
            }
        }
        .frame(minHeight: 44)
        .task {
            guard !isLoaded else { return }
            if let fetched = try? await WeatherService.shared.attribution {
                withAnimation(.easeInOut(duration: 0.35)) {
                    attribution = fetched
                    isLoaded = true
                }
            }
        }
    }
    
    private func attributionContent(_ attribution: WeatherAttribution) -> some View {
        VStack(spacing: 6) {
            if let logoURL {
                AsyncImage(url: logoURL) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(height: 16)
                } placeholder: {
                    appleWeatherFallback
                }
            } else {
                appleWeatherFallback
            }
            
            Text("Data has been modified")
                .font(.caption)
                .foregroundStyle(.secondary)
            
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
    }
    
    private var appleWeatherFallback: some View {
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

// MARK: - ToolbarButtonStyle

struct ToolbarButtonStyle: ButtonStyle {
    var tint: Color?
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint ?? .primary)
            .frame(width: 20, height: 20)
            .padding(10)
            .background(Circle().fill(.white))
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
            if let tint {
                self.tint(tint)
            } else {
                self
            }
        } else if #available(iOS 18.0, *) {
            self.buttonStyle(ToolbarButtonStyle(tint: tint))
        } else {
            self
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
