import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let location: LocationStore
    let weather: WeatherStore
    let waxSelection: WaxSelectionStore
    let recommendation: RecommendationStore

    init() {
        let location = LocationStore()
        let weather = WeatherStore(locationStore: location)
        let waxSelection = WaxSelectionStore()
        let recommendation = RecommendationStore(weatherStore: weather, waxSelectionStore: waxSelection)
        
        self.location = location
        self.weather = weather
        self.waxSelection = waxSelection
        self.recommendation = recommendation
    }
}
