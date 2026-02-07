import Charts
import SwiftUI

/// A richer explanation of how the snow type was determined.
/// Includes snowfall + temperature charts for recent days.
struct SnowAssessmentExplainView: View {
  let assessment: SnowSurfaceAssessment
  let pastDaily: [DailyHistorySummary]

  private struct DayPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let snowCM: Double
    let minC: Double?
    let maxC: Double?

    var avgC: Double? {
      switch (minC, maxC) {
      case (let min?, let max?): return (min + max) / 2
      default: return nil
      }
    }
  }

  /// WeatherService builds `pastDaily` sorted newest-first.
  /// For charting we want chronological order, last 10.
  private var last10Days: [DayPoint] {
    let days = Array(pastDaily.prefix(10)).reversed()
    return days.map { day in
      DayPoint(
        date: day.date,
        snowCM: max(0, day.snowfallAmountCM ?? 0),
        minC: day.temperatureMinC,
        maxC: day.temperatureMaxC
      )
    }
  }

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

      Section("Snowfall (last 10 days)") {
        Chart(last10Days) { point in
          BarMark(
            x: .value("Date", point.date, unit: .day),
            y: .value("Snow (cm)", point.snowCM)
          )
          .foregroundStyle(.blue.gradient)
        }
        .chartYAxisLabel("cm")
        .chartXScale(range: .plotDimension(padding: 8))
        .frame(height: 160)

        let sum3 = last10Days.suffix(3).map(\.snowCM).reduce(0, +)
        let sum7 = last10Days.suffix(7).map(\.snowCM).reduce(0, +)
        LabeledContent("Sum 3 days", value: String(format: "%.1f cm", sum3))
        LabeledContent("Sum 7 days", value: String(format: "%.1f cm", sum7))
      }

      Section("Temperature (last 10 days)") {
        Chart {
          ForEach(last10Days) { point in
            if let min = point.minC, let max = point.maxC {
              AreaMark(
                x: .value("Date", point.date, unit: .day),
                yStart: .value("Min", min),
                yEnd: .value("Max", max)
              )
              .foregroundStyle(.orange.opacity(0.25))

              LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Avg", (min + max) / 2)
              )
              .foregroundStyle(.orange)
              .lineStyle(.init(lineWidth: 2))
            } else if let avg = point.avgC {
              LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Avg", avg)
              )
              .foregroundStyle(.orange)
              .lineStyle(.init(lineWidth: 2))
            }
          }

          RuleMark(y: .value("Freezing", 0))
            .foregroundStyle(.secondary)
            .lineStyle(.init(lineWidth: 1, dash: [4, 3]))
        }
        .chartYAxisLabel("°C")
        .chartXScale(range: .plotDimension(padding: 8))
        .frame(height: 180)
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
        LabeledContent(
          "Date", value: assessment.date.formatted(date: .abbreviated, time: .shortened))
        LabeledContent(
          "Recent snow", value: formattedOptional(assessment.recentSnowCM, suffix: " cm"))
        LabeledContent("Min temp", value: formattedOptional(assessment.minTempC, suffix: " °C"))
        LabeledContent("Max temp", value: formattedOptional(assessment.maxTempC, suffix: " °C"))
        LabeledContent(
          "Humidity", value: formattedOptional(assessment.humidity.map { $0 * 100 }, suffix: " %"))
      }
    }
    .navigationTitle("Snow assessment")
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  private func formattedOptional(_ value: Double?, suffix: String) -> String {
    guard let value else { return "–" }
    return String(format: "%.1f%@", value, suffix)
  }
}

@available(iOS 16.0, *)
#Preview {
  NavigationStack {
    Text("SnowAssessmentExplainView")
      .padding()
  }
}
