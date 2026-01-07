//
//  AppState.swift
//  waxappv2
//
//  Central application state that coordinates all stores.
//

import Foundation
import Combine

/// Main application state container that manages all stores.
/// Uses dependency injection to allow for testability and flexibility.
@MainActor
final class AppState: ObservableObject {
    /// Store managing location services
    let location: LocationStore
    
    /// Store managing weather data
    let weather: WeatherStore
    
    /// Store managing wax selection
    let waxSelection: WaxSelectionStore
    
    /// Store managing wax recommendations
    let recommendation: RecommendationStore

    /// Initializes the app state with default dependencies.
    convenience init() {
        let location = LocationStore()
        let weather = WeatherStore(locationStore: location)
        let waxSelection = WaxSelectionStore()
        let recommendation = RecommendationStore(weatherStore: weather, waxSelectionStore: waxSelection)
        
        self.init(
            location: location,
            weather: weather,
            waxSelection: waxSelection,
            recommendation: recommendation
        )
        
        // Start weather observation after initialization
        weather.startObserving(locationStore: location)
    }
    
    /// Initializes the app state with custom dependencies for testing.
    /// - Parameters:
    ///   - location: The location store
    ///   - weather: The weather store
    ///   - waxSelection: The wax selection store
    ///   - recommendation: The recommendation store
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
