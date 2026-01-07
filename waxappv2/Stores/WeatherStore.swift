//
//  WeatherStore.swift
//  waxappv2
//
//  Store managing weather data fetching and observation.
//

import Foundation
import CoreLocation
import Combine

/// Store that manages weather data for the current location.
/// Observes location changes and automatically fetches weather updates.
@MainActor
final class WeatherStore: ObservableObject, WeatherStoreProtocol {
    /// Status of weather data operations
    enum Status {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// Current status of weather operations
    @Published private(set) var status: Status = .idle
    
    /// Current weather and snow pack summary
    @Published private(set) var summary: WeatherAndSnowpackSummary?
    
    /// The current temperature in Celsius, or nil if not available
    var temperature: Int? {
        guard let first = summary?.weather.next24Hours.first else { return nil }
        return Int(first.temperatureC)
    }
    
    /// The current snow surface assessment, or nil if not available
    var currentAssessment: SnowSurfaceAssessment? {
        summary?.currentAssessment
    }
    
    /// Publisher for summary changes (required by WeatherStoreProtocol)
    var summaryPublisher: AnyPublisher<WeatherAndSnowpackSummary?, Never> {
        $summary.eraseToAnyPublisher()
    }

    /// Task for observing location changes
    private var observeTask: Task<Void, Never>?
    
    /// Weather service client for fetching data
    private let service: WeatherServiceClient

    /// Initializes the store with dependencies.
    /// - Parameters:
    ///   - locationStore: The location store to observe for location changes
    ///   - service: The weather service client (defaults to WeatherServiceClient)
    init(locationStore: LocationStore, service: WeatherServiceClient? = nil) {
        self.service = service ?? WeatherServiceClient()
    }
    
    /// Starts observing location changes and fetching weather data.
    /// Call this after initialization to begin location observation.
    func startObserving(locationStore: LocationStore) {
        observeTask = Task { [weak self] in
            guard let self else { return }
            
            var last: AppLocation? = nil
            
            // LocationStore.locationStream() yields the current location immediately
            for await location in locationStore.locationStream() {
                // Skip duplicate locations
                if location == last { continue }
                last = location
                
                guard let location else {
                    self.status = .idle
                    self.summary = nil
                    continue
                }
                
                await self.fetch(for: location)
            }
        }
    }
    
    deinit {
        observeTask?.cancel()
    }
    
    /// Manually refresh weather data for a specific location.
    /// - Parameter location: The location to fetch weather for
    func refresh(location: AppLocation) async {
        await fetch(for: location)
    }

    /// Fetches weather data for a location.
    /// - Parameter location: The location to fetch weather for
    private func fetch(for location: AppLocation) async {
        status = .loading
        do {
            let s = try await service.fetchWeatherAndAssessSnow(for: location.coordinate)
            self.summary = s
            status = .loaded
        } catch {
            status = .failed(error.localizedDescription)
            self.summary = nil
        }
    }
}
