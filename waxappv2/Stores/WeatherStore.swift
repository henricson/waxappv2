// `waxappv2/Stores/WeatherStore.swift`

import Foundation
import Observation

/// Store that manages weather data for the current location.
@Observable
final class WeatherStore {
    
    enum Status: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }
    
    // MARK: - Public State
    
    private(set) var status: Status = .idle
    private(set) var summary: WeatherAndSnowpackSummary?
    
    /// Current temperature in Celsius
    var temperature: Int? {
        guard let first = summary?.weather.next24Hours.first else { return nil }
        return Int(first.temperatureC)
    }
    
    /// Current snow surface assessment
    var currentAssessment: SnowSurfaceAssessment? {
        summary?.currentAssessment
    }
    
    // MARK: - Dependencies
    
    private let locationStore: LocationStore
    private let service: WeatherServiceClient
    
    // MARK: - Private
    
    private var lastFetchedLocation: AppLocation?
    
    init(locationStore: LocationStore, service: WeatherServiceClient) {
        self.locationStore = locationStore
        self.service = service
    }
    
    // MARK: - Public Methods
    
    /// Call this when you need weather data. Fetches only if location changed.
    func fetchIfNeeded() async {
        guard let location = locationStore.location else {
            status = .idle
            summary = nil
            lastFetchedLocation = nil
            return
        }
        
        guard location != lastFetchedLocation else { return }
        await fetch(for: location)
    }
    
    /// Force refresh for current location
    func refresh() async {
        guard let location = locationStore.location else { return }
        await fetch(for: location)
    }
    
    // MARK: - Private
    
    private func fetch(for location: AppLocation) async {
        status = .loading
        do {
            let result = try await service.fetchWeatherAndAssessSnow(for: location.coordinate)
            summary = result
            lastFetchedLocation = location
            status = .loaded
        } catch {
            status = .failed(error.localizedDescription)
            summary = nil
        }
    }
}
