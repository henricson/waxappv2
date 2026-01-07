import Foundation
import CoreLocation
import Combine

/// Store managing weather data and snow surface assessments.
/// Observes location changes and fetches weather data automatically.
@MainActor
final class WeatherStore: ObservableObject {
    /// Status of the weather data fetch operation
    enum Status {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    /// The current fetch status
    @Published private(set) var status: Status = .idle
    
    /// The current weather and snow surface assessment summary
    @Published private(set) var summary: WeatherAndSnowpackSummary?
    
    /// Convenience property for accessing current temperature
    var temperature: Int? {
        guard let first = summary?.weather.next24Hours.first else { return nil }
        return Int(first.temperatureC)
    }
    
    /// Convenience property for accessing current snow surface assessment
    var currentAssessment: SnowSurfaceAssessment? {
        summary?.currentAssessment
    }

    private var observeTask: Task<Void, Never>?
    private let service: WeatherServiceClient
    private let errorHandler: WeatherErrorHandler

    /// Convenience initializer with default dependencies.
    convenience init(locationStore: LocationStore) {
        self.init(
            locationStore: locationStore,
            service: WeatherServiceClient(),
            errorHandler: StandardWeatherErrorHandler()
        )
    }
    
    /// Designated initializer with dependency injection.
    /// - Parameters:
    ///   - locationStore: The location store to observe for location changes
    ///   - service: The weather service client for fetching data
    ///   - errorHandler: The error handler for processing fetch errors
    init(
        locationStore: LocationStore,
        service: WeatherServiceClient,
        errorHandler: WeatherErrorHandler
    ) {
        self.service = service
        self.errorHandler = errorHandler
        
        // Start observing location changes
        startObservingLocation(locationStore)
    }
    
    deinit {
        observeTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Manually refresh weather data for the current location.
    /// - Parameter location: The location to fetch weather for
    func refresh(location: AppLocation) async {
        await fetch(for: location)
    }
    
    // MARK: - Private Methods
    
    /// Starts observing location changes and fetches weather when location changes.
    /// - Parameter locationStore: The location store to observe
    private func startObservingLocation(_ locationStore: LocationStore) {
        observeTask = Task { [weak self] in
            guard let self else { return }
            
            var last: AppLocation? = nil
            
            // LocationStore.locationStream() yields the current location immediately
            for await location in locationStore.locationStream() {
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

    /// Fetches weather data for a specific location.
    /// - Parameter location: The location to fetch weather for
    private func fetch(for location: AppLocation) async {
        status = .loading
        do {
            let s = try await service.fetchWeatherAndAssessSnow(for: location.coordinate)
            self.summary = s
            status = .loaded
        } catch {
            let errorMessage = errorHandler.handle(error)
            status = .failed(errorMessage)
            self.summary = nil
        }
    }
}
