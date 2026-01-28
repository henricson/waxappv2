//
//  WeatherAnalyzer.swift
//  waxappv2
//
//  Created by Herman Henriksen on 28/01/2026.
//

protocol WeatherAnalyzer {
    var weatherDataPoints: [WeatherDataPointModel] { get }
    
    var currentSnowType: SnowType { get }
    
    var currentTemperature: Double { get }
}

extension WeatherAnalyzer {
    var currentSnowType: SnowType {
        return SnowType.fineGrained
    }
}

struct MainWeatherAnalyzer : WeatherAnalyzer {
    var weatherDataPoints: [WeatherDataPointModel]
    
    private var amountOfSnowFallInMMCountsAsNewSnow: Double = 1.0
    
    // New snow is reference for this snow group
    private var amountOfHoursWhereNewSnowIsNewSnow: Int = 24
    private var amountOfHoursBeforeNewSnowIsFineGrained: Int = 48
    private var amountOfHoursBeforeFineGrainedIsOldSnow: Int = 72
    
    private var averageTemperature: Double = 0.0
    private var averageSnowfall: Double = 0.0
    
    var currentTemperature: Double {
        weatherDataPoints.last?.averageTemperature ?? 0.0
    }
}
