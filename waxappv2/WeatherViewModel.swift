//
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
    @Published var currentAssessment: SnowSurfaceAssessment?
    @Published var pastDailyAssessments: [SnowSurfaceAssessment] = []

    private let service = WeatherServiceClient()

    func fetch(for location: CLLocation) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let summary = try await service.fetchWeatherAndAssessSnow(for: location)
            currentAssessment = summary.currentAssessment
            pastDailyAssessments = summary.pastDailyAssessments
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

