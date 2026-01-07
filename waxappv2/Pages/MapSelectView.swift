//
//  MapSelectView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 17/12/2025.
//

import SwiftUI
import MapKit
import Combine

struct MapSelectView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationStore: LocationStore
    
    // Default to a zoomed-out view if no location exists
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var searchQuery: String = ""
    @StateObject private var searchModel = PlaceSearchCompleter()
    
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
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                let point = value.location
                                if let coordinate = proxy.convert(point, from: .local) {
                                    withAnimation {
                                        selectedCoordinate = coordinate
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onEnded { value in
                                switch value {
                                case .second(true, let drag?):
                                    let point = drag.startLocation
                                    if let coordinate = proxy.convert(point, from: .local) {
                                        withAnimation {
                                            selectedCoordinate = coordinate
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                    )
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
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a place")
            .searchSuggestions {
                ForEach(searchModel.suggestions.indices, id: \.self) { idx in
                    let c = searchModel.suggestions[idx]
                    Button {
                        performSearch(completion: c)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.title).font(.body.weight(.semibold))
                            if !c.subtitle.isEmpty {
                                Text(c.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .onChange(of: searchQuery) { _, newValue in
                searchModel.update(query: newValue)
            }
            .onSubmit(of: .search) {
                performSearch(query: searchQuery)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Current", systemImage: "location.fill") {
                        useCurrentLocation()
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
        if let currentLoc = locationStore.location {
            let region = MKCoordinateRegion(
                center: currentLoc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            position = .region(region)
            
            // If it is a manual override, pre-select the pin
            if locationStore.isManualOverride {
                selectedCoordinate = currentLoc.coordinate
            }
        }
    }
    
    private func confirmLocation() {
        guard let coordinate = selectedCoordinate else { return }
        
        let newLocation = AppLocation(
            lat: coordinate.latitude,
            lon: coordinate.longitude,
            placeName: nil // will be fetched
        )
        
        // Update the manager with the manual override
        locationStore.setManualLocation(newLocation)
        dismiss()
    }
    
    private func useCurrentLocation() {
        guard let loc = locationStore.location else { return }
        let region = MKCoordinateRegion(
            center: loc.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        withAnimation {
            selectedCoordinate = loc.coordinate
            position = .region(region)
        }
    }
    
    private func performSearch(completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let item = response?.mapItems.first else { return }
            let coord = item.placemark.coordinate
            let region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            withAnimation {
                selectedCoordinate = coord
                position = .region(region)
            }
        }
    }
    
    private func performSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let item = response?.mapItems.first else { return }
            let coord = item.placemark.coordinate
            let region = MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            withAnimation {
                selectedCoordinate = coord
                position = .region(region)
            }
        }
    }
}

#Preview {
    MapSelectView()
        .environmentObject(AppState().location)
}

final class PlaceSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private let completer: MKLocalSearchCompleter
    
    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        // Optionally constrain to addresses/landmarks
        self.completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func update(query: String) {
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { [weak self] in
            self?.suggestions = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // You could surface errors if desired
        DispatchQueue.main.async { [weak self] in
            self?.suggestions = []
        }
    }
}
