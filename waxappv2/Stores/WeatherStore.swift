// `waxappv2/Stores/WeatherStore.swift`

import Foundation
import CoreLocation
import Combine

/// Store that manages weather data for the current location.
/// Observes location changes and automatically fetches weather updates.
@MainActor
final class WeatherStore: ObservableObject, WeatherStoreProtocol {

    var locationStore: LocationStore

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

    /// Weather service client for fetching data
    private let service: WeatherServiceClient

    /// Task that observes location changes
    private var observeTask: Task<Void, Never>?

    /// Initializes the store with dependencies.
    /// - Parameters:
    ///   - locationStore: The location store to observe for location changes
    ///   - service: The weather service client (defaults to WeatherServiceClient)
    init(locationStore: LocationStore, service: WeatherServiceClient? = nil) {
        self.service = service ?? WeatherServiceClient()
        self.locationStore = locationStore
        startObservingLocationChanges()
    }

    deinit {
        observeTask?.cancel()
    }

    /// Manually refresh weather data for a specific location.
    /// - Parameter location: The location to fetch weather for
    func refresh(location: AppLocation) async {
        await fetch(for: location)
    }

    /// Starts observing the LocationStore for location updates and fetches when it changes.
    private func startObservingLocationChanges() {
        observeTask?.cancel()
        observeTask = Task { [weak self] in
            guard let self else { return }

            var last: AppLocation? = nil

            for await location in self.locationStore.locationStream() {
                guard location != last else { continue }
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
