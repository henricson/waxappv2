//
//  MapSelectView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 17/12/2025.
//

import SwiftUI
import MapKit
import Combine

// Used to measure view height so we can size the suggestions list to its content.
private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MapSelectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var locationStore: LocationStore

    // Default to a zoomed-out view if no location exists
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCoordinate: CLLocationCoordinate2D?

    @State private var searchQuery: String = ""
    @StateObject private var searchModel = PlaceSearchModel()
    @FocusState private var isSearchFocused: Bool

    // Used to re-center the map after resetting manual override.
    @State private var shouldRecenterOnNextLocationUpdate: Bool = false

    // Dynamic sizing for the suggestions list.
    @State private var suggestionsContentHeight: CGFloat = 0
    private let suggestionsMaxHeight: CGFloat = 320
    private let suggestionsMinHeight: CGFloat = 56

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                MapReader { proxy in
                    Map(position: $position) {
                        UserAnnotation()
                        if let selectedCoordinate {
                            Marker("Selected Location", coordinate: selectedCoordinate)
                                .tint(.blue)
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .ignoresSafeArea(.all, edges: .bottom)
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                // If keyboard is open, first tap dismisses it.
                                if isSearchFocused {
                                    isSearchFocused = false
                                    return
                                }

                                if let coordinate = proxy.convert(value.location, from: .local) {
                                    withAnimation {
                                        selectedCoordinate = coordinate
                                    }
                                }
                            }
                    )
                }

                // Bottom Controls Layer
                VStack(spacing: 0) {
                    // Floating "My Location" Button
                    HStack {
                        Spacer()
                        Button(action: useCurrentLocation) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .padding(12)
                                .background(.thickMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 12)
                    }

                    // Search Suggestions (pop up from bottom)
                    if isSearchFocused && !searchModel.suggestions.isEmpty {
                        let mostRelevant = searchModel.suggestions.first
                        let listSuggestions = mostRelevant == nil ? searchModel.suggestions : Array(searchModel.suggestions.dropFirst())

                        let content: some View = VStack(spacing: 0) {
                            ForEach(listSuggestions) { suggestion in
                                suggestionRow(suggestion)

                                if suggestion.id != listSuggestions.last?.id {
                                    Divider()
                                        .padding(.leading, 12)
                                }
                            }

                            if let mostRelevant {
                                if !listSuggestions.isEmpty {
                                    Divider()
                                }

                                VStack(spacing: 0) {
                                    Text("Top result")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.top, 8)
                                        .padding(.bottom, 2)

                                    suggestionRow(mostRelevant)
                                }
                            }
                        }

                        // Measure actual rendered content height.
                        let measured = suggestionsContentHeight > 0 ? suggestionsContentHeight : suggestionsMinHeight
                        let targetHeight = min(max(suggestionsMinHeight, measured), suggestionsMaxHeight)
                        let shouldScroll = measured > suggestionsMaxHeight

                        Group {
                            if shouldScroll {
                                ScrollView {
                                    content
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear
                                                    .preference(key: HeightPreferenceKey.self, value: geo.size.height)
                                            }
                                        )
                                }
                            } else {
                                content
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear
                                                .preference(key: HeightPreferenceKey.self, value: geo.size.height)
                                        }
                                    )
                            }
                        }
                        .scrollIndicators(.hidden)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .frame(height: targetHeight)
                        .onPreferenceChange(HeightPreferenceKey.self) { newHeight in
                            if abs(newHeight - suggestionsContentHeight) > 1 {
                                suggestionsContentHeight = newHeight
                            }
                        }
                    }

                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 20))

                        TextField("Search for a place", text: $searchQuery)
                            .focused($isSearchFocused)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onChange(of: searchQuery) { _, newValue in
                                searchModel.update(query: newValue)
                            }
                            .submitLabel(.search)
                            .onSubmit {
                                // Enter should pick the most relevant suggestion (shown as "Top result")
                                // when available; otherwise fallback to a normal free-text search.
                                if let top = searchModel.suggestions.first {
                                    Task { await performSearch(completion: top.completion) }
                                    isSearchFocused = false
                                    searchModel.clear()

                                    let title = top.completion.title
                                    let subtitle = top.completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                    searchQuery = subtitle.isEmpty ? title : "\(title), \(subtitle)"
                                } else {
                                    Task { await performSearch(query: searchQuery) }
                                }
                            }
                            .padding(.vertical, 4)

                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                searchModel.clear()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 18))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, selectedCoordinate != nil ? 10 : 20)

                    // Confirm Button (Only if location selected)
                    if selectedCoordinate != nil {
                        Button(action: confirmLocation) {
                            Text("Use this location")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
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
            .onChange(of: locationStore.location) { _, newLocation in
                guard shouldRecenterOnNextLocationUpdate else { return }
                guard let newLocation else { return }
                // If we still have a manual override, ignore updates (LocationStore won't send them anyway).
                guard locationStore.locationStatus != .manual_override else { return }

                let region = MKCoordinateRegion(
                    center: newLocation.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                withAnimation {
                    selectedCoordinate = newLocation.coordinate
                    position = .region(region)
                }

                shouldRecenterOnNextLocationUpdate = false
            }
        }
    }

    private func setupInitialMapState() {
        if let currentLoc = locationStore.location {
            let region = MKCoordinateRegion(
                center: currentLoc.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            position = .region(region)

            if locationStore.locationStatus == .manual_override {
                selectedCoordinate = currentLoc.coordinate
            }
        }
    }

    private func confirmLocation() {
        guard let coordinate = selectedCoordinate else { return }

        let newLocation = AppLocation(
            lat: coordinate.latitude,
            lon: coordinate.longitude,
            placeName: nil
        )

        print("MapSelectView: Setting manual location to (\(newLocation.lat), \(newLocation.lon))")
        locationStore.setManualLocation(newLocation)
        dismiss()
    }

    private func useCurrentLocation() {
        // If the user previously confirmed a manual location, `locationStore.location` will be that
        // manual value. Treat this button as a reset-to-GPS action.
        if locationStore.locationStatus == .manual_override {
            print("MapSelectView: Clearing manual override and requesting GPS location")
            shouldRecenterOnNextLocationUpdate = true
            locationStore.clearManualLocation()

            // Clear the manual pin right away so the UI matches the intent.
            withAnimation {
                selectedCoordinate = nil
            }

            return
        }

        // Check authorization status first
        if locationStore.authorizationStatus == .notDetermined {
            // Request authorization and location together
            shouldRecenterOnNextLocationUpdate = true
            locationStore.requestAuthorization()
            locationStore.requestLocation()
            return
        }
        
        if locationStore.authorizationStatus == .denied || locationStore.authorizationStatus == .restricted {
            // Handle denied/restricted - could show an alert here
            print("MapSelectView: Location access denied or restricted")
            return
        }

        // If no manual override is active, just center on the current GPS location (if we have one).
        guard let loc = locationStore.location else {
            // Kick off a request in case we don't have a fix yet.
            shouldRecenterOnNextLocationUpdate = true
            locationStore.requestLocation()
            return
        }

        let region = MKCoordinateRegion(
            center: loc.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        withAnimation {
            selectedCoordinate = loc.coordinate
            position = .region(region)
        }
    }

    @MainActor
    private func performSearch(completion: MKLocalSearchCompletion) async {
        guard let (coord, region) = await searchModel.search(completion: completion) else { return }
        withAnimation {
            selectedCoordinate = coord
            position = .region(region)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        guard let (coord, region) = await searchModel.search(query: query) else { return }
        withAnimation {
            selectedCoordinate = coord
            position = .region(region)
        }
    }

    @ViewBuilder
    private func suggestionRow(_ suggestion: PlaceSearchModel.Suggestion) -> some View {
        let title = suggestion.completion.title
        let subtitle = suggestion.completion.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let fullAddressLine = subtitle.isEmpty ? title : "\(title), \(subtitle)"

        Button {
            Task { await performSearch(completion: suggestion.completion) }
            isSearchFocused = false
            searchModel.clear()
            searchQuery = fullAddressLine
        } label: {
            Text(fullAddressLine)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
    }
}

#Preview {
    MapSelectView()
        .environmentObject(AppState().location)
}

@MainActor
final class PlaceSearchModel: NSObject, ObservableObject {
    struct Suggestion: Identifiable, Equatable {
        let id: UUID
        let completion: MKLocalSearchCompletion

        init(_ completion: MKLocalSearchCompletion) {
            self.id = UUID()
            self.completion = completion
        }

        static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
            lhs.completion.title == rhs.completion.title && lhs.completion.subtitle == rhs.completion.subtitle
        }
    }

    @Published private(set) var suggestions: [Suggestion] = []

    private let completer: MKLocalSearchCompleter
    private var inFlightSearch: MKLocalSearch?

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
        self.completer.resultTypes = [.address, .pointOfInterest]
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clear()
            completer.queryFragment = ""
            return
        }
        completer.queryFragment = trimmed
    }

    func clear() {
        suggestions = []
    }

    func search(completion: MKLocalSearchCompletion) async -> (CLLocationCoordinate2D, MKCoordinateRegion)? {
        let request = MKLocalSearch.Request(completion: completion)
        return await search(request: request)
    }

    func search(query: String) async -> (CLLocationCoordinate2D, MKCoordinateRegion)? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        return await search(request: request)
    }

    private func search(request: MKLocalSearch.Request) async -> (CLLocationCoordinate2D, MKCoordinateRegion)? {
        // Cancel any in-flight searches to avoid races and stale callbacks.
        inFlightSearch?.cancel()

        let search = MKLocalSearch(request: request)
        inFlightSearch = search

        return await withCheckedContinuation { continuation in
            search.start { [weak self] response, _ in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                // Ignore stale callback if another search has started.
                guard self.inFlightSearch === search else {
                    continuation.resume(returning: nil)
                    return
                }

                self.inFlightSearch = nil

                guard let item = response?.mapItems.first else {
                    continuation.resume(returning: nil)
                    return
                }

                let coord = item.placemark.coordinate
                let region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                continuation.resume(returning: (coord, region))
            }
        }
    }
}

extension PlaceSearchModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // MapKit calls this on the main actor already in practice, but keep it deterministic.
        self.suggestions = completer.results.map { Suggestion($0) }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Don’t surface this as a crash; just clear suggestions.
        self.suggestions = []
    }
}
