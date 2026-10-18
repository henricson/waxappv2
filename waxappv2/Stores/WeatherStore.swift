import CoreLocation
import Foundation
import Observation
import OSLog

private let logger = Logger(subsystem: "com.squarewave.waxappv2", category: "Weather")

/// Store that manages weather data for the current location.
@MainActor
@Observable
final class WeatherStore {

  // MARK: - State

  private(set) var currentTemperature: Double = -7.0
  private(set) var weatherDataPoints: [WeatherDataPointModel] = []

  /// Set when the most recent fetch failed. Cleared on a successful fetch.
  private(set) var fetchError: Error?

  /// True once at least one fetch has succeeded for the current location.
  private(set) var hasLoadedWeather = false

  private(set) var isFetching = false

  /// Name of the provider that supplied the current data, for attribution.
  private(set) var sourceName: String = "Apple Weather"

  // MARK: - Derived signals

  /// Signal extraction is shared with the widgets.
  private var digest: WeatherDigest { WeatherDigest(points: weatherDataPoints) }

  private var latestPoint: WeatherDataPointModel? { digest.latestPoint }

  var currentHumidity: Double? { digest.currentHumidity }

  var currentSnowDepthCM: Double? { digest.currentSnowDepthCM }

  /// Liquid precipitation over the last 24 h, mm.
  var recentRainMM: Double { digest.recentRainMM }

  /// Snowfall over the last 24 h, mm.
  var recentSnowMM: Double { digest.recentSnowMM }

  /// True when meaningful snow fell in the most recent hour on record.
  var isSnowingNow: Bool { digest.isSnowingNow }

  /// Air temperature change over the last 6 h, °C.
  var temperatureTrendC: Double? { digest.temperatureTrendC }

  /// Snow type derived from current temperature and weather history.
  /// Classification logic lives in `SnowTypeClassifier`.
  var currentSnowType: SnowType {
    SnowTypeClassifier.classify(
      currentTemperature: currentTemperature,
      weatherDataPoints: weatherDataPoints
    )
  }

  // MARK: - Dependencies

  private let locationStore: LocationStore
  private let weatherProviderFactory: WeatherProviderFactory

  /// Convenience initializer using Apple's WeatherKit, the app's only
  /// weather source: it covers the ten-day history and the hourly humidity
  /// the classifier needs, and its licence allows commercial use.
  convenience init(locationStore: LocationStore) {
    self.init(
      locationStore: locationStore,
      weatherProviderFactory: WeatherKitWeatherProviderFactory()
    )
  }

  init(
    locationStore: LocationStore,
    weatherProviderFactory: WeatherProviderFactory
  ) {
    self.locationStore = locationStore
    self.weatherProviderFactory = weatherProviderFactory
  }

  // MARK: - Fetching

  @discardableResult
  func fetchWeather() async -> Bool {
    guard !isFetching else { return hasLoadedWeather }
    guard let location = locationStore.location else {
      logger.debug("No location available for weather fetch")
      return false
    }

    isFetching = true
    defer { isFetching = false }

    let provider = weatherProviderFactory.makeProvider()
    let clLocation = CLLocation(latitude: location.lat, longitude: location.lon)
    let now = Date()
    let tenDaysAgo =
      Calendar.current.date(byAdding: .day, value: -10, to: now)
      ?? now.addingTimeInterval(-10 * 24 * 3600)
    let interval = DateInterval(start: tenDaysAgo, end: now)

    do {
      let dataPoints = try await provider.data(
        for: clLocation, in: interval, granularity: .hourly)

      guard !dataPoints.isEmpty else {
        throw WeatherStoreError.noData
      }

      weatherDataPoints = dataPoints.sorted { $0.start < $1.start }
      if let latest = latestPoint {
        currentTemperature = latest.averageTemperature
      }
      sourceName = provider.sourceName
      fetchError = nil
      hasLoadedWeather = true
      logger.debug("Weather loaded: \(self.currentTemperature, format: .fixed(precision: 1))°C")
      return true
    } catch {
      fetchError = error
      logger.error("Weather fetch failed: \(error.localizedDescription, privacy: .public)")
      return false
    }
  }

  /// Clears loaded data when the location changes, so stale readings are
  /// never presented as if they belonged to the new place.
  func reset() {
    weatherDataPoints = []
    hasLoadedWeather = false
    fetchError = nil
  }
}

enum WeatherStoreError: LocalizedError {
  case noData

  var errorDescription: String? {
    String(localized: "Error_NoWeatherData")
  }
}
