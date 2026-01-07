//
//  MapSelectView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 17/12/2025.
//

import SwiftUI
import MapKit

struct MapSelectView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationManager: LocationManager
    
    // Default to a zoomed-out view if no location exists
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapReader { proxy in
                    Map(position: $position) {
                        // Show the user's actual GPS location if available
                        UserAnnotation()
                        
                        // Show the selected pin
                        if let selectedCoordinate {
                            Marker("Selected Location", coordinate: selectedCoordinate)
                                .tint(.blue)
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .onTapGesture { screenPoint in
                        // Convert screen tap to map coordinate
                        if let coordinate = proxy.convert(screenPoint, from: .local) {
                            withAnimation {
                                selectedCoordinate = coordinate
                            }
                        }
                    }
                }
                
                // Confirm Button
                if selectedCoordinate != nil {
                    Button(action: confirmLocation) {
                        Text("Use this location")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                            .padding()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                setupInitialMapState()
            }
        }
    }
    
    private func setupInitialMapState() {
        // If we already have a location (manual or GPS), center the map there
        if let currentLoc = locationManager.effectiveLocation {
            let region = MKCoordinateRegion(
                center: currentLoc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            position = .region(region)
            
            // If it is a manual override, pre-select the pin
            if locationManager.isManualOverride {
                selectedCoordinate = currentLoc.coordinate
            }
        }
    }
    
    private func confirmLocation() {
        guard let coordinate = selectedCoordinate else { return }
        
        let newLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        
        // Update the manager with the manual override
        locationManager.setManualLocation(newLocation)
        dismiss()
    }
}

#Preview {
    MapSelectView()
        .environmentObject(LocationManager())
}
