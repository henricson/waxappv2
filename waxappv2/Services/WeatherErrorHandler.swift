//
//  WeatherErrorHandler.swift
//  waxappv2
//
//  Standardized error handling for weather operations.
//

import Foundation

/// Protocol for handling weather-related errors.
protocol WeatherErrorHandler {
    /// Handles a weather fetch error.
    /// - Parameter error: The error that occurred
    /// - Returns: A user-friendly error message
    func handle(_ error: Error) -> String
}

/// Standard implementation of weather error handler.
/// Provides user-friendly error messages for common error scenarios.
final class StandardWeatherErrorHandler: WeatherErrorHandler {
    func handle(_ error: Error) -> String {
        // Convert to localized description or provide more specific messages
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection available"
            case .timedOut:
                return "Request timed out. Please try again"
            case .cannotFindHost, .cannotConnectToHost:
                return "Cannot reach weather service"
            default:
                return "Network error: \(urlError.localizedDescription)"
            }
        }
        
        return error.localizedDescription
    }
}
