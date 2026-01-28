//
//  WeatherAnalyzer.swift
//  waxappv2
//
//  Created by Herman Henriksen on 28/01/2026.
//

import Foundation

// MARK: - Configuration (Value Object)

/// All tunable thresholds in one place. Implementations receive this as a
/// dependency so every magic number can be overridden or tested in isolation.
public struct SnowpackThresholds: Sendable {
    // Snow amount boundaries (centimeters)
    public let significantSnowCM: Double          // ≥ this → "significant" new layer
    public let lightSnowCM: Double                // ≥ this → surface-refreshing dusting

    // Temperature boundaries (Celsius)
    public let freezingPoint: Double              // 0 °C
    public let moistSnowBoundary: Double          // above this → moist conditions possible
    public let coldSnowBoundary: Double           // below this → cold/dry conditions
    public let veryColdBoundary: Double           // below this → very slow metamorphism
    public let wetSnowTempThreshold: Double       // above this → definitely wet
    public let slushTempThreshold: Double         // above this → very wet / slushy

    // Time windows (hours)
    public let newSnowWindowHours: Int            // snow remains "new" for this long
    public let fineGrainedMaxHours: Int           // after this → old grained
    public let meltRelevanceWindowHours: Int      // melt affects surface for this long

    // Humidity
    public let highHumidityThreshold: Double      // ≥ this → high humidity

    /// Production defaults matching the existing WeatherService constants.
    public static let defaults = SnowpackThresholds(
        significantSnowCM: 2.0,
        lightSnowCM: 0.5,
        freezingPoint: 0.0,
        moistSnowBoundary: -1.0,
        coldSnowBoundary: -7.0,
        veryColdBoundary: -12.0,
        wetSnowTempThreshold: 0.5,
        slushTempThreshold: 2.0,
        newSnowWindowHours: 48,
        fineGrainedMaxHours: 96,
        meltRelevanceWindowHours: 72,
        highHumidityThreshold: 0.80
    )
}

// MARK: - Snowpack State (State Machine)

/// The evolving state of the snowpack surface driven by weather events.
/// Processed chronologically; each data point may trigger a transition.
public struct SnowpackState: Sendable {
    /// Hours elapsed since the last significant snowfall (≥ significantSnowCM).
    public var hoursSinceSignificantSnow: Int

    /// Hours elapsed since the last melt event (temps above wetSnowTempThreshold).
    /// `nil` means no recent melt is tracked (either never happened or fell outside
    /// the melt-relevance window).
    public var hoursSinceLastMelt: Int?

    /// Total snowfall (cm) accumulated since the most recent melt event.
    /// Used to decide whether new snow has "covered" a previously wet surface.
    public var snowDepthSinceLastMelt: Double

    /// Whether the snowpack contained free liquid water at any point within
    /// the melt-relevance window. Required precondition for Group 5 (frozen corn).
    public var wasWetRecently: Bool

    /// Number of consecutive hours the max temperature has been above freezing.
    public var consecutiveHoursAboveFreezing: Int

    /// Zero-state: no history known.
    public static let initial = SnowpackState(
        hoursSinceSignificantSnow: 0,
        hoursSinceLastMelt: nil,
        snowDepthSinceLastMelt: 0,
        wasWetRecently: false,
        consecutiveHoursAboveFreezing: 0
    )

    /// Whether the surface qualifies as refrozen at the given average temperature.
    /// True only when: a melt occurred recently, it has not been covered by
    /// significant new snow since, and the current temperature is below freezing.
    public func isRefrozenSurface(
        currentTempC: Double,
        thresholds: SnowpackThresholds
    ) -> Bool {
        guard let hoursSinceMelt = hoursSinceLastMelt else { return false }
        guard hoursSinceMelt <= thresholds.meltRelevanceWindowHours else { return false }
        guard snowDepthSinceLastMelt < thresholds.significantSnowCM else { return false }
        guard currentTempC < thresholds.freezingPoint else { return false }
        return true
    }
}

// MARK: - Derived Conditions (Input to Rules)

/// A pre-computed snapshot of conditions for a single time window (hour or day).
/// Rules operate on this rather than raw data, keeping the decision logic clean.
public struct DerivedConditions: Sendable {
    /// Snow that fell during this window, in centimeters.
    public let snowfallCM: Double
    /// Minimum temperature during this window, in °C.
    public let minTempC: Double
    /// Maximum temperature during this window, in °C.
    public let maxTempC: Double
    /// Average temperature during this window, in °C.
    public let avgTempC: Double
    /// Relative humidity (0–1) during this window.
    public let humidity: Double

    // --- Boolean flags derived from thresholds ---

    public let hasSignificantSnow: Bool
    public let hasLightSnow: Bool
    public let isAboveFreezing: Bool
    public let isCurrentlyWet: Bool
    public let isMoist: Bool
    public let isVeryCold: Bool
    public let isCold: Bool
    public let isHighHumidity: Bool
    public let isRefrozen: Bool

    /// Builds the full set of derived conditions from raw weather values and current state.
    public init(
        snowfallCM: Double,
        minTempC: Double,
        maxTempC: Double,
        humidity: Double,
        state: SnowpackState,
        thresholds: SnowpackThresholds
    ) {
        self.snowfallCM = snowfallCM
        self.minTempC = minTempC
        self.maxTempC = maxTempC
        self.avgTempC = (minTempC + maxTempC) / 2.0
        self.humidity = humidity

        self.hasSignificantSnow = snowfallCM >= thresholds.significantSnowCM
        self.hasLightSnow = snowfallCM >= thresholds.lightSnowCM
        self.isAboveFreezing = maxTempC > thresholds.freezingPoint
        self.isCurrentlyWet = maxTempC >= thresholds.wetSnowTempThreshold
        self.isMoist = maxTempC >= thresholds.moistSnowBoundary && maxTempC < thresholds.wetSnowTempThreshold
        self.isVeryCold = self.avgTempC <= thresholds.veryColdBoundary
        self.isCold = self.avgTempC <= thresholds.coldSnowBoundary
        self.isHighHumidity = humidity >= thresholds.highHumidityThreshold
        self.isRefrozen = state.isRefrozenSurface(
            currentTempC: self.avgTempC,
            thresholds: thresholds
        )
    }
}

// MARK: - Assessment Result (Output of Rules)

/// The outcome produced by a single classification rule.
public struct AssessmentResult: Sendable {
    /// The determined snow surface type.
    public let snowType: SnowType
    /// Confidence the rule has in its classification.
    public let confidence: AssessmentConfidence
    /// Localization key describing why this result was chosen.
    public let reasonKey: String
    /// Template parameters for the reason string.
    public let reasonParams: [String: String]
}

// MARK: - Classification Rule (Strategy / Chain of Responsibility)

/// A single priority-ordered rule in the snow classification decision tree.
/// Rules are evaluated in order; the first one whose `canApply` returns `true`
/// produces the final `AssessmentResult`.
public protocol SnowClassificationRule: Sendable {
    /// Whether this rule applies given the current conditions and state.
    func canApply(
        conditions: DerivedConditions,
        state: SnowpackState,
        thresholds: SnowpackThresholds
    ) -> Bool

    /// Produces the assessment result. Only called when `canApply` returned `true`.
    func apply(
        conditions: DerivedConditions,
        state: SnowpackState,
        thresholds: SnowpackThresholds
    ) -> AssessmentResult
}

// MARK: - State Transition (State Machine Transitions)

/// Defines how a single weather observation mutates the snowpack state.
/// Applied after classification so the state is ready for the next window.
public protocol SnowpackStateTransition: Sendable {
    /// Whether this transition should fire for the given conditions.
    func shouldApply(
        conditions: DerivedConditions,
        state: SnowpackState,
        thresholds: SnowpackThresholds
    ) -> Bool

    /// Mutates the state in place. Only called when `shouldApply` returned `true`.
    func apply(
        conditions: DerivedConditions,
        state: inout SnowpackState,
        thresholds: SnowpackThresholds
    )
}

// MARK: - Weather Analyzer (Orchestrator)

/// Top-level protocol that drives the full analysis pipeline:
///   1. Converts raw `WeatherDataPointModel` data into `DerivedConditions`
///   2. Walks the time series chronologically, maintaining `SnowpackState`
///   3. At each step, evaluates the ordered chain of `SnowClassificationRule`s
///   4. After classification, applies `SnowpackStateTransition`s
///   5. Collects all per-window assessments and exposes aggregate statistics
public protocol WeatherAnalyzer: Sendable {

    // MARK: - Input

    /// The raw hourly or daily precipitation data to analyze.
    var weatherDataPoints: [WeatherDataPointModel] { get }

    // MARK: - Configuration

    /// The thresholds governing all classification decisions.
    var thresholds: SnowpackThresholds { get }

    /// The ordered list of classification rules. First match wins.
    var classificationRules: [any SnowClassificationRule] { get }

    /// The ordered list of state transitions applied after each classification.
    var stateTransitions: [any SnowpackStateTransition] { get }

    // MARK: - Analysis Results

    /// The full chronological sequence of assessments, one per data point.
    var assessments: [SnowSurfaceAssessment] { get }

    /// The classification for the most recent (last) data point.
    var currentSnowType: SnowType { get }

    /// The confidence of the most recent assessment.
    var currentConfidence: AssessmentConfidence { get }

    // MARK: - Aggregate Statistics

    /// Average temperature across all data points (°C).
    var averageTemperature: Double { get }

    /// Average snowfall across all data points (mm).
    var averageSnowfall: Double { get }

    /// Total snowfall across all data points (mm).
    var totalSnowfall: Double { get }

    /// Total rainfall (including sleet/mixed/hail) across all data points (mm).
    var totalRainfall: Double { get }

    /// The snowfall threshold (mm) at which snowfall is considered "new snow"
    /// capable of resetting the surface classification.
    var newSnowThresholdMM: Double { get }

    /// Number of hours (or days, depending on granularity) that snowfall
    /// is still classified as "new snow" before transitioning to fine-grained.
    var windowSizeForNewSnow: Int { get }

    /// Number of hours (or days) before fine-grained snow transitions to old grained.
    var windowSizeBeforeOldSnow: Int { get }
}
