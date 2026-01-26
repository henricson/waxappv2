import Foundation


@MainActor
@Observable
final class AppState {
    let location: LocationStore
    let weather: WeatherStore
    let waxSelection: WaxSelectionStore
    let recommendation: RecommendationStore
    let storeManager: StoreManager

    init() {
        let location = LocationStore()
        let weather = WeatherStore(locationStore: location, service: WeatherServiceClient())
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
