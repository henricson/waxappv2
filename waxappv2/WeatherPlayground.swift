//
//  WeatherPlayground.swift
//  waxappv2
//
//  Created by Herman Henriksen on 19/10/2025.
//

import Playgrounds
import CoreLocation
import WeatherKit

#Playground {
    // Location of Oslo
    let location = CLLocation(latitude: 59.9138, longitude: 10.7383)
    
    let weatherService = WeatherService()
    
    // Ten days ago
    let startDay: Int = 10
    
    let endDay: Int = 0
    
    // Specify the date range for the last 7 days
    let calendar = Calendar.current
    let endDate = Date()
    let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
    
    // Fetch hourly weather data
    let weatherData = try await weatherService.weather(for: location, including: .hourly(startDate: startDate, endDate: endDate))
    
    
    
    print(weatherData)
    
}
