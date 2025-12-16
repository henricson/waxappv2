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
    
    // Binding that drives the SnowTypeButtons
    private var selectedGroupBinding: Binding<SnowType> {
        Binding<SnowType>(
            get: {
                userSelectedGroup
                ?? weather.currentAssessment?.group
                ?? .fineGrained // default fallback when nothing available
            },
            set: { newValue in
                // Get snowType based of weather
                let weatherValue = weather.currentAssessment?.group
                // If the set snowType is not same as weather
                if weatherValue == nil || weatherValue != newValue {
                    // Manual override
                    userSelectedGroup = newValue
                    // Reset location information
                    locationManager.resetToNoLocation()
                } else {
                    // Re-selected the weather-derived value: clear override
                    userSelectedGroup = nil
                }
                // Update recommendations when user picks
                recVM.snowType = newValue
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView(.vertical) {
                    VStack(spacing: 0) {
                        if let recommended = recVM.recommended.first {
                            HeaderCanView(recommendedWax: recommended.wax)
                        }else {
                            Text("Outside of range")
                                .frame(height: 200)
                        }
                        ZStack {
                            GanttDiagram(temperature: $weather.temperature, snowType: selectedGroupBinding)
                            
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
                    .onChange(of: weather.temperature) {
                        recVM.temperature = weather.temperature
                    }

                    .onAppear {
                        recVM.temperature = weather.temperature
                        recVM.snowType = selectedGroupBinding.wrappedValue
                    
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
                                colors: [Color(hex: recommended.wax.primaryColor) ?? .blue, .black],
                                startPoint: .top, endPoint: .bottom
                            )
                            .ignoresSafeArea(edges: .top)
                            .transition(.opacity)
                            // Key the view so SwiftUI treats a new recommendation as a new view
                            .id(recommended.wax.primaryColor)
                        }
                    }
                    // Animate when the identifier (primaryColor) changes
                    .animation(.easeIn, value: recVM.recommended.first?.wax.primaryColor)
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
                    Menu("Snowtype", systemImage: "snowflake") {
                        Picker("Snow Type", selection: selectedGroupBinding) {
                            ForEach(SnowType.allCases, id: \.self) { group in
                                Label(group.titleNo, systemImage: group.iconName).tag(group)
                            }
                        }
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
    
    

    



   
}



#Preview {
    @Previewable @StateObject var locationManager = LocationManager()

        
        WaxRecommendView()
            .environmentObject(locationManager)
    
}

