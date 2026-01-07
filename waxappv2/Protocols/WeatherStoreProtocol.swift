//
//  WeatherStoreProtocol.swift
//  waxappv2
//
//  Protocol abstraction for WeatherStore to enable decoupling and testing.
//

import Foundation
import Combine

/// Protocol defining the public interface of WeatherStore.
/// Allows for decoupling and easier testing of dependent components.
@MainActor
protocol WeatherStoreProtocol: ObservableObject {
    /// The current weather summary, or nil if not available
    var summary: WeatherAndSnowpackSummary? { get }
    
    /// The current temperature in Celsius, or nil if not available
    var temperature: Int? { get }
    
    /// The current snow surface assessment, or nil if not available
    var currentAssessment: SnowSurfaceAssessment? { get }
    
    /// Publisher for summary changes
    var summaryPublisher: AnyPublisher<WeatherAndSnowpackSummary?, Never> { get }
    
    /// Manually refresh weather data for a given location
    /// - Parameter location: The location to fetch weather for
    func refresh(location: AppLocation) async
}
