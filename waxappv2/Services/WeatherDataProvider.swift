//
//  WeatherDataProvider.swift
//  waxappv2
//
//  Protocol for providing weather data to other components.
//

import Foundation
import Combine

/// Protocol for components that provide weather data.
/// Abstracts the weather data source to enable testing and loose coupling.
protocol WeatherDataProvider {
    /// Publisher that emits weather summaries when they change
    var summaryPublisher: AnyPublisher<WeatherAndSnowpackSummary?, Never> { get }
}

/// Extension to make WeatherStore conform to WeatherDataProvider.
extension WeatherStore: WeatherDataProvider {
    var summaryPublisher: AnyPublisher<WeatherAndSnowpackSummary?, Never> {
        $summary.eraseToAnyPublisher()
    }
}
