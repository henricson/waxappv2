import SwiftUI

/// Shows how `WeatherServiceClient` decided the current `SnowSurfaceAssessment`.
struct SnowAssessmentDebugView: View {
    let assessment: SnowSurfaceAssessment

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    Image(systemName: assessment.group.iconName)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assessment.group.title)
                            .font(.headline)
                        Text(assessment.confidence.localizedName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Group \(assessment.swixGroup)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
            }

            Section("Reasons") {
                if assessment.reasons.isEmpty {
                    Text("No details available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(assessment.reasons.enumerated()), id: \.offset) { _, reason in
                        Text(reason)
                    }
                }
            }

            Section("Inputs") {
                LabeledContent("Date", value: assessment.date.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Recent snow", value: formattedOptional(assessment.recentSnowCM, suffix: " cm"))
                LabeledContent("Min temp", value: formattedOptional(assessment.minTempC, suffix: " °C"))
                LabeledContent("Max temp", value: formattedOptional(assessment.maxTempC, suffix: " °C"))
                LabeledContent("Humidity", value: formattedOptional(assessment.humidity.map { $0 * 100 }, suffix: " %"))
                LabeledContent("Hours above 0", value: formattedOptional(assessment.hoursAboveZero))
                LabeledContent("Hours below -5", value: formattedOptional(assessment.hoursBelowMinus5))
                LabeledContent("Refreeze detected", value: assessment.refreezeDetected == true ? "Yes" : "No")
                LabeledContent("Days since melt", value: formattedOptional(assessment.daysSinceLastMelt))
                LabeledContent("Days since significant snow", value: formattedOptional(assessment.daysSinceSignificantSnow))
            }

            Section("Raw rule keys") {
                if assessment.reasonKeys.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(assessment.reasonKeys.enumerated()), id: \.offset) { index, key in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(key)
                                .font(.caption.monospaced())
                            if index < assessment.reasonParams.count {
                                Text(String(describing: assessment.reasonParams[index]))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Snow assessment")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private func formattedOptional<T>(_ value: T?) -> String {
        guard let value else { return "–" }
        return String(describing: value)
    }

    private func formattedOptional(_ value: Double?, suffix: String) -> String {
        guard let value else { return "–" }
        return String(format: "%.1f%@", value, suffix)
    }
}

#Preview {
    NavigationStack {
        SnowAssessmentDebugView(
            assessment: SnowSurfaceAssessment(
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
        )
    }
}
