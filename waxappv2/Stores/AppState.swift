import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let location: LocationStore
    let weather: WeatherStore
    let waxSelection: WaxSelectionStore
    let recommendation: RecommendationStore
    let storeManager: StoreManager

    init() {
        let location = LocationStore()
        let weather = WeatherStore(locationStore: location)
        weather.startObserving(locationStore: location)
        
        let waxSelection = WaxSelectionStore()
        let recommendation = RecommendationStore(weatherStore: weather, waxSelectionStore: waxSelection)
        let storeManager = StoreManager()
        
        self.location = location
        self.weather = weather
        self.waxSelection = waxSelection
        self.recommendation = recommendation
        self.storeManager = storeManager
    }
}
