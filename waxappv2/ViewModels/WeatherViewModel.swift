//  WeatherViewModel.swift
//  waxappv2
//
//  Created by Herman Henriksen on 18/10/2025.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class WeatherViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    // Uses information for the next
    @Published var currentAssessment: SnowSurfaceAssessment?
    @Published var pastDailyAssessments: [SnowSurfaceAssessment] = []

    // Temperature handling
    // Weather-provided temperature in °C (default 0.0)
    @Published var temperature: Int = -5
  

    private let service = WeatherServiceClient()

    func fetch(for location: CLLocation) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let summary = try await service.fetchWeatherAndAssessSnow(for: location)
            currentAssessment = summary.currentAssessment
            pastDailyAssessments = summary.pastDailyAssessments
            print(currentAssessment.debugDescription)
            
            // Derive current temperature from the first hourly entry (now/next)
            if let firstHour = summary.weather.next24Hours.first {
                temperature = Int(firstHour.temperatureC)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

