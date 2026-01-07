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
    
    // UI State
    @State private var showMapSelection = false
    @State private var showLocationPermissionAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
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
                                            Label("Move back", systemImage: target > recStore.temperature ? "arrow.right" : "arrow.left",)
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
                            get: { recStore.snowType },
                            set: { newValue in
                                // If the user taps the same as weather, maybe clear override?
                                // For now, just set the override.
                                recStore.userSelectedSnowType = newValue
                            }))
                        .padding(.vertical, 20)
                        
                        ZStack {
                            GanttDiagram(temperature: $recStore.temperature, snowType: recStore.snowType)
                                .id(recStore.snowType)
                                .padding(.top, 50)
                            TemperatureGauge(temperature: recStore.temperature)
                        }
                        
                    }
                }
                .background(
                    ZStack {
                        Color.clear.ignoresSafeArea(edges: .top)
                        if let recommended = recStore.recommended.first {
                            LinearGradient(
                                colors: [Color(hex: recommended.wax.primaryColor) ?? .blue, .black],
                                startPoint: .top, endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .top)
                            .transition(.opacity)
                            .id(recommended.wax.primaryColor)
                        }
                    }
                        .animation(.easeIn, value: recStore.recommended.first?.wax.primaryColor)
                )
            }
            .navigationTitle(locStore.location?.placeName ?? "")
            
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
                            handleReset()
                        } label: {
                            Image(systemName: recStore.isOverridden ? "location.slash.fill" : "location.fill")
                            
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
            .onChange(of: locStore.authorizationStatus) { _, _ in
                locStore.requestAuthorization()
            }
            
            // Note: Stores handle their own interconnection (Location -> Weather -> Recs),
            // so we don't need manual .onChange chains here anymore!
            
            .onAppear {
                if locStore.authorizationStatus == .notDetermined {
                    locStore.requestAuthorization()
                }
                locStore.requestLocation()
            }
           
        }
    }
    
    // MARK: - Helper Methods
    
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
}
