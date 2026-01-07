import Foundation
import Combine

/// Application-wide state container managing all stores.
/// Coordinates the lifecycle and dependencies between stores.
@MainActor
final class AppState: ObservableObject {
    /// Store managing location services and data
    let location: LocationStore
    
    /// Store managing weather data and forecasts
    let weather: WeatherStore
    
    /// Store managing wax selection state
    let waxSelection: WaxSelectionStore
    
    /// Store managing wax recommendations
    let recommendation: RecommendationStore

    /// Convenience initializer with default dependencies for production use.
    convenience init() {
        let location = LocationStore()
        let weather = WeatherStore(locationStore: location)
        let waxSelection = WaxSelectionStore()
        let recommendation = RecommendationStore(
            weatherStore: weather,
            waxSelectionStore: waxSelection
        )
        
        self.init(
            location: location,
            weather: weather,
            waxSelection: waxSelection,
            recommendation: recommendation
        )
    }
    
    /// Designated initializer with dependency injection.
    /// Enables testing by allowing mock stores to be injected.
    /// - Parameters:
    ///   - location: The location store instance
    ///   - weather: The weather store instance
    ///   - waxSelection: The wax selection store instance
    ///   - recommendation: The recommendation store instance
    init(
        location: LocationStore,
        weather: WeatherStore,
        waxSelection: WaxSelectionStore,
        recommendation: RecommendationStore
    ) {
        self.location = location
        self.weather = weather
        self.waxSelection = waxSelection
        self.recommendation = recommendation
    }
}
