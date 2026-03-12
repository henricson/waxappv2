import CoreLocation
import Foundation
import Observation

/// Store that manages weather data for the current location.
@MainActor
@Observable
final class WeatherStore {
  var currentTemperature: Double = -7.0

  var weatherDataPoints: [WeatherDataPointModel] = []

  /// Error state for UI feedback
  var fetchError: Error?
  var isFetching: Bool = false

  /// Snow type derived from current temperature and weather history.
  /// Classification logic lives in `SnowTypeClassifier`.
  var currentSnowType: SnowType {
    SnowTypeClassifier.classify(
      currentTemperature: currentTemperature,
      weatherDataPoints: weatherDataPoints
    )
  }

  private let locationStore: LocationStore
  private let weatherProviderFactory: WeatherProviderFactory

  /// Convenience initializer using the default WeatherKit provider.
  convenience init(locationStore: LocationStore) {
    self.init(locationStore: locationStore, weatherProviderFactory: WeatherKitWeatherProviderFactory())
  }

  init(
    locationStore: LocationStore,
    weatherProviderFactory: WeatherProviderFactory
  ) {
    self.locationStore = locationStore
    self.weatherProviderFactory = weatherProviderFactory
  }

  func fetchWeather() async {
    guard !isFetching else { return }
    isFetching = true
    fetchError = nil
    defer { isFetching = false }

    #if DEBUG
      print("🌤️ Fetching weather!")
    #endif

    let weatherProvider = weatherProviderFactory.makeProvider()
    guard let location = locationStore.location else {
      #if DEBUG
        print("⚠️ No location available for weather fetch")
      #endif
      return
    }

    let clLocation = CLLocation(latitude: location.lat, longitude: location.lon)
    let now = Date()
    guard let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: now) else {
      #if DEBUG
        print("⚠️ Failed to calculate date range")
      #endif
      return
    }
    let interval = DateInterval(start: tenDaysAgo, end: now)

    do {
      let dataPoints = try await weatherProvider.data(
        for: clLocation, in: interval, granularity: .hourly)
      weatherDataPoints = dataPoints
      if let lastDataPoint = weatherDataPoints.last {
        currentTemperature = lastDataPoint.averageTemperature
        #if DEBUG
          print("✅ Weather fetched! Temperature: \(currentTemperature)°C")
        #endif
      }
    } catch {
      fetchError = error
      #if DEBUG
        print("❌ Failed to fetch weather data:", error)
      #endif
    }
  }
}
