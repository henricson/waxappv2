import Foundation
import CoreLocation
import Combine

@MainActor
final class WeatherStore: ObservableObject {
    enum Status {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var summary: WeatherAndSnowpackSummary?
    
    // Derived properties for easy access/observation
    var temperature: Int? {
        guard let first = summary?.weather.next24Hours.first else { return nil }
        return Int(first.temperatureC)
    }
    
    var currentAssessment: SnowSurfaceAssessment? {
        summary?.currentAssessment
    }

    private var observeTask: Task<Void, Never>?
    private let service: WeatherServiceClient

    init(locationStore: LocationStore, service: WeatherServiceClient? = nil) {
        self.service = service ?? WeatherServiceClient()
        
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
    
    deinit {
        observeTask?.cancel()
    }
    
    /// Exposed for manual refresh if needed, though location changes drive it mainly.
    /// To force a refresh for the *current* location, one might need to trigger it manually.
    func refresh(location: AppLocation) async {
        await fetch(for: location)
    }

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
