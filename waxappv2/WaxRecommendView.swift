//
//  ContentView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import SwiftUI
import CoreLocation

struct WaxRecommendView: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var weather = WeatherViewModel()
    @StateObject private var recVM = RecommendedWaxesViewModel()
    
    // User override
    @State private var userSelectedGroup: SnowType?
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        if let recommended = recVM.recommended.first {
                            HeaderCanView(recommendedWax: recommended)
                            
                            
                            
                        }else {
                            HeaderCanView(recommendedWax: swixWaxes.first!)
                        }
                        
                        
                        
                        // Horizontal button-like picker
                        ZStack {
                            GanttDiagram(temperature: $weather.temperature)
                            
                            TemperatureGauge(temperature: $weather.temperature)
                            
                        }.contentMargins(.top, 20)
                            .padding(.top, 20)
                        
                        Text("\(weather.temperature)°C")
                            .font(.title2)
                            .padding(10)
                            .cornerRadius(50)
                            .glassEffect()
                        
                        
                    }
                    
                    .onChange(of: locationManager.authorizationStatus) { _, _ in
                        locationManager.requestAuthorizationIfNeeded()
                    }
                    .onChange(of: locationManager.lastLocation) { _, newLoc in
                        guard let loc = newLoc else { return }
                        Task { await weather.fetch(for: loc) }
                    }
                    .onChange(of: effectiveGroup) { _, newGroup in
                        recVM.effectiveGroup = newGroup
                    }
                    .onChange(of: weather.temperature) {
                        recVM.weatherTempC = $0
                    }
                    .onAppear {
                        // Seed recommendation inputs
                        recVM.set(group: effectiveGroup, tempC: weather.temperature)
                        
                        // Don’t auto-fetch on appear if the user has overridden the snow type.
                        guard userSelectedGroup == nil else { return }
                        locationManager.requestAuthorizationIfNeeded()
                        if let loc = locationManager.lastLocation {
                            Task { await weather.fetch(for: loc) }
                        }
                    }
                }
                .background(
                    ZStack {
                        // Base background
                        Color.clear
                            .ignoresSafeArea(edges: .top)

                        if let recommended = recVM.recommended.first {
                            LinearGradient(
                                colors: [Color(hex: recommended.primaryColor) ?? .blue, .black],
                                startPoint: .top, endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .top)
                            .transition(.opacity)
                            // Key the view so SwiftUI treats a new recommendation as a new view
                            .id(recommended.primaryColor)
                        }
                    }
                    // Animate when the identifier (primaryColor) changes
                    .animation(.easeIn, value: recVM.recommended.first?.primaryColor)
                )
            }
            .navigationTitle("Kirkenes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Map", systemImage: "map") {
                        
                    }
                }
                ToolbarItem() {
                    Button("Snowtype", systemImage: "snowflake") {
                        
                    }
                }
                ToolbarItem {
                    LocationButton()
                        .onChange(of: locationManager.lastLocation) { _, newLoc in
                            if newLoc != nil {
                                userSelectedGroup = nil
                            }
                        }
                }
          
            }
        }
    }
    
    

    



    // Binding that drives the SnowTypeButtons
    private var selectedGroupBinding: Binding<SnowType> {
        Binding<SnowType>(
            get: {
                userSelectedGroup
                ?? weather.currentAssessment?.group
                ?? .fineGrained // default fallback when nothing available
            },
            set: { newValue in
                let weatherValue = weather.currentAssessment?.group
                if weatherValue == nil || weatherValue != newValue {
                    // User override: store it and reset location state so the button reads "Fetch location"
                    userSelectedGroup = newValue
                    locationManager.resetToNoLocation()
                } else {
                    // Re-selected the weather-derived value: clear override
                    userSelectedGroup = nil
                }
                // Update recommendations when user picks
                recVM.effectiveGroup = newValue
            }
        )
    }

    private var effectiveGroup: SnowType {
        userSelectedGroup ?? weather.currentAssessment?.group ?? .fineGrained
    }
}



#Preview {
    @Previewable @StateObject var locationManager = LocationManager()

        
        WaxRecommendView()
            .environmentObject(locationManager)
    
}

