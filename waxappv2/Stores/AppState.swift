import CoreLocation
import Foundation
import Observation

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
    let waxSelection = WaxSelectionStore()
    let weather: WeatherStore

    if DemoMode.isEnabled {
      weather = WeatherStore(
        locationStore: location,
        weatherProviderFactory: DemoWeatherProviderFactory()
      )
    } else {
      weather = WeatherStore(locationStore: location)
    }

    let recommendation = RecommendationStore(
      weatherStore: weather, waxSelectionStore: waxSelection)
    let storeManager = StoreManager()

    self.location = location
    self.weather = weather
    self.waxSelection = waxSelection
    self.recommendation = recommendation
    self.storeManager = storeManager

    if DemoMode.isEnabled {
      applyDemoMode()
    }
  }

  /// Puts the app into the fixed state the App Store screenshots expect.
  private func applyDemoMode() {
    // Every capture starts from a known library: exactly the series asked
    // for, or the kit a new install in that region would get.
    if DemoMode.seriesIDs.isEmpty {
      waxSelection.resetToDefaults()
    } else {
      waxSelection.replaceSelection(with: Set(DemoMode.seriesIDs))
    }

    if DemoMode.skipsOnboarding {
      waxSelection.markOnboardingComplete()
    } else {
      waxSelection.resetOnboarding()
    }
    storeManager.applyDemoAccess()

    recommendation.activeDomain = DemoMode.domain
    recommendation.isAdvancedMode = DemoMode.showsAdvanced
    recommendation.effectiveTemperature = DemoMode.temperature
    recommendation.effectiveSnowType = DemoMode.snowType

    location.setManualLocation(
      AppLocation(
        lat: DemoMode.coordinate.latitude,
        lon: DemoMode.coordinate.longitude,
        placeName: DemoMode.placeName
      ))
  }
}
