import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let location: LocationStore
    let weather: WeatherStore
    let recommendation: RecommendationStore

    init() {
        let location = LocationStore()
        let weather = WeatherStore(locationStore: location)
        let recommendation = RecommendationStore(weatherStore: weather)
        
        self.location = location
        self.weather = weather
        self.recommendation = recommendation
    }
}
