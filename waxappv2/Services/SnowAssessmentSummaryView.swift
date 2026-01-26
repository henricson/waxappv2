import SwiftUI

struct SnowAssessmentSummaryView: View {
    let assessment: SnowSurfaceAssessment
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var title: String { assessment.group.title }
    private var icon: String { assessment.group.iconName }
    private var reason: String { assessment.reasons.first ?? "" }
    private var confidence: AssessmentConfidence { assessment.confidence }
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !reason.isEmpty {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(localized: "Confidence_Label", defaultValue: "Confidence"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ConfidenceBadge(confidence: confidence)
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 0.5)
        )
        .padding(.horizontal)  // Added outer horizontal padding here
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Snow assessment")
        .accessibilityValue("\(title). \(reason). Confidence \(confidence.localizedName)")
    }
}

private struct ConfidenceBadge: View {
    let confidence: AssessmentConfidence
    
    private var color: Color {
        switch confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }
    
    var body: some View {
        Text(confidence.localizedName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(color.opacity(0.6), lineWidth: 0.75)
            )
            .accessibilityLabel("Confidence")
            .accessibilityValue(confidence.localizedName)
    }
}

#Preview {
    let assessment = SnowSurfaceAssessment(
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
    
    return VStack(alignment: .leading, spacing: 12) {
        SnowAssessmentSummaryView(assessment: assessment)
            .padding()
        Spacer()
    }
}

