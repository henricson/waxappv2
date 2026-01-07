//
//  ContentView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import CoreLocation
import TipKit

struct MainView: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var weather = WeatherViewModel()
    @StateObject private var recVM = RecommendationViewModel()
    
   
    
    // UI State
    @State private var userSelectedGroup: SnowType?
    @State private var showMapSelection = false
    @State private var showLocationPermissionAlert = false
    
    private var currentSnowType : SnowType {
        userSelectedGroup
        ?? recVM.snowType
    }
    
    private var isOverridenSnowTypeOrTemperature : Bool {
        return (weather.temperature != recVM.temperature)
        || userSelectedGroup != nil
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        Group {
                            if let recommended = recVM.recommended.first {
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
                                    if let target = nearestRecommendedTemperature(for: currentSnowType, from: recVM.temperature) {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.35)) {
                                                recVM.temperature = target
                                            }
                                        } label: {
                                            Label("Move back", systemImage: target > recVM.temperature ? "arrow.right" : "arrow.left",)
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.regular)
                                        .accessibilityHint("Scrolls the temperature scale to the nearest range with recommendations")
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }.frame(height: 200)
                        
                        SnowTypeButtons(selected: Binding(
                            get: {
                                currentSnowType
                            },
                            set: { newValue in
                                handleSnowTypeChange(newValue)
                            }))
                        .padding(.vertical, 20)
                        
                        ZStack {
                            GanttDiagram(temperature: $recVM.temperature, snowType: currentSnowType)
                                .id(currentSnowType)
                                .padding(.top, 50)
                            TemperatureGauge(temperature: recVM.temperature)
                        }
                        
                    }
                }
                .background(
                    ZStack {
                        Color.clear.ignoresSafeArea(edges: .top)
                        if let recommended = recVM.recommended.first {
                            LinearGradient(
                                colors: [Color(hex: recommended.wax.primaryColor) ?? .blue, .black],
                                startPoint: .top, endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .top)
                            .transition(.opacity)
                            .id(recommended.wax.primaryColor)
                        }
                    }
                        .animation(.easeIn, value: recVM.recommended.first?.wax.primaryColor)
                )
            }
            .navigationTitle(locationManager.placeName ?? "")
            
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // MARK: - Left: Map Selection
                ToolbarItem(placement: .topBarLeading) {
                    Button("Map", systemImage: "map") {
                        showMapSelection = true
                    }
                }
                
                
                ToolbarItem(placement: .topBarTrailing) {
                        
                        
                        Button {
                            handleFetchLocationAndSetWeather()
                        } label: {
                            Image(systemName: isOverridenSnowTypeOrTemperature ? "location.slash.fill" : "location.fill")
                            
                        }
                }
                

            }
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
                Text("Please enable location services in settings to use your GPS position.")
            }
            .onChange(of: locationManager.authorizationStatus) { _, _ in
                locationManager.requestAuthorizationIfNeeded()
            }
            
            // Update of users location
            .onChange(of: locationManager.lastLocation) { _, newLoc in
                guard let loc = newLoc else { return }
                Task { await weather.fetch(for: loc) }
            }
            // Add observer for manual location specifically
            .onChange(of: locationManager.manualLocation) { _, newLoc in
                guard let loc = newLoc else { return }
                Task { await weather.fetch(for: loc) }
            }
            
            // Set the temperature when weather forecast is fetched
            .onChange(of: weather.temperature) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    recVM.temperature = weather.temperature
                }
            }
            
            // Set the snow type when weather forecast is fetched (and assessed)
            .onChange(of: weather.currentAssessment) { _, newAssessment in
                guard let newGroup = newAssessment?.group else { return }
                // Remove any user override of snow type
                userSelectedGroup = nil
                recVM.snowType = newGroup
            }
            
            .onAppear {
                //recVM.temperature = weather.temperature
                handleFetchLocationAndSetWeather()
             
            }
           
        }
    }
    
    
    // MARK: - Helper Methods
    
    private func nearestRecommendedTemperature(for snowType: SnowType, from current: Int) -> Int? {
        // Gather all ranges for the given snow type
        let ranges: [TempRangeC] = swixWaxes.flatMap { wax in
            wax.ranges[snowType] ?? []
        }
        guard !ranges.isEmpty else { return nil }
        
        // Find the nearest point on any range to the current temperature
        var bestTarget: Int = current
        var bestDistance: Int = Int.max
        
        for r in ranges {
            // Clamp the current temp to this range to get the nearest point on the interval
            let clamped = max(r.min, min(current, r.max))
            let distance = abs(clamped - current)
            if distance < bestDistance {
                bestDistance = distance
                bestTarget = clamped
            }
        }
        return bestTarget
    }
    
    /**
     When snowType changes due to user selection, resetLocationInfo
     */
    private func handleSnowTypeChange(_ newValue: SnowType) {
        let weatherValue = weather.currentAssessment?.group
        
        if weatherValue == nil || weatherValue != newValue {
            userSelectedGroup = newValue
            locationManager.resetToNoLocation()
        } else {
            // If they selected what was already the weather recommendation,
            // we might want to clear the manual override
            userSelectedGroup = nil
        }
        recVM.snowType = newValue
    }
    
    // MARK: - Helper Methods
    
    private func handleFetchLocationAndSetWeather() {
        switch locationManager.authorizationStatus {
        case .denied, .restricted:
            showLocationPermissionAlert = true
        case .notDetermined:
            locationManager.requestAuthorizationIfNeeded()
        case .authorizedAlways, .authorizedWhenInUse:
            // 1. Clear any manual map selection
            locationManager.clearManualOverride()
            // 2. Clear manual snow type
            userSelectedGroup = nil
            // 3. Force a refresh of GPS
            locationManager.fetchLocationOnce()
            // 4. Reset temperature override
            withAnimation(.easeInOut(duration: 0.35)) {
                recVM.temperature = weather.temperature
            }
            
        @unknown default:
            break
        }
    }
}

#Preview {
    @Previewable @StateObject var locationManager = LocationManager()
    
    MainView()
        .environmentObject(locationManager)
}
