import SwiftUI

struct SnowAssessmentSummaryView: View {
    let assessment: SnowSurfaceAssessment
    
    private var confidence: AssessmentConfidence { assessment.confidence }
    
    private var confidenceColor: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
    
    private var icon: String { assessment.group.iconName }
    
    private var description: String {
        assessment.reasons.first ?? "No details available."
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            
            Text(description)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer(minLength: 4)
            
            Text(confidence.localizedName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(confidenceColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(confidenceColor.opacity(0.15))
                )
        }
        
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Snow assessment")
        .accessibilityValue("\(description). Confidence \(confidence.localizedName)")
    }
}

#Preview {
    let assessmentHigh = SnowSurfaceAssessment(
        id: UUID(),
        date: Date(),
        group: .fineGrained,
        confidence: .high,
        reasonKeys: ["Snow_Reason_FineGrained_Recent"],
        reasonParams: [["days": "2"]],
        recentSnowCM: 1.0,
        minTempC: -8.0,
        maxTempC: -3.0,
        hoursAboveZero: 0,
        hoursBelowMinus5: 4,
        refreezeDetected: false,
        daysSinceLastMelt: 10,
        daysSinceSignificantSnow: 2,
        humidity: 0.55
    )
    
    let assessmentMedium = SnowSurfaceAssessment(
        id: UUID(),
        date: Date(),
        group: .transformedMoistFine,
        confidence: .medium,
        reasonKeys: ["Snow_Reason_Transformed_MeltRefreeze"],
        reasonParams: [["cycles": "3"]],
        recentSnowCM: 0.0,
        minTempC: -4.0,
        maxTempC: 2.0,
        hoursAboveZero: 6,
        hoursBelowMinus5: 0,
        refreezeDetected: true,
        daysSinceLastMelt: 1,
        daysSinceSignificantSnow: 5,
        humidity: 0.70
    )
    
    let assessmentLow = SnowSurfaceAssessment(
        id: UUID(),
        date: Date(),
        group: .wetCorn,
        confidence: .low,
        reasonKeys: [],
        reasonParams: [],
        recentSnowCM: 0.0,
        minTempC: 0.0,
        maxTempC: 5.0,
        hoursAboveZero: 12,
        hoursBelowMinus5: 0,
        refreezeDetected: false,
        daysSinceLastMelt: 0,
        daysSinceSignificantSnow: 8,
        humidity: 0.85
    )
    
     ZStack {
        LinearGradient(colors: [.blue, .purple], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        
        VStack(spacing: 10) {
            SnowAssessmentSummaryView(assessment: assessmentHigh)
            SnowAssessmentSummaryView(assessment: assessmentMedium)
            SnowAssessmentSummaryView(assessment: assessmentLow)
        }
        .padding()
    }
}

