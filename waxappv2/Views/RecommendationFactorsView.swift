//
//  RecommendationFactorsView.swift
//  waxappv2
//
//  Advanced mode: shows *why* the top pick scored as it did, so experienced
//  skiers can disagree with the app on an informed basis.
//

import SwiftUI

struct RecommendationFactorsView: View {
  let recommendation: WaxRecommendation

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header

      ForEach(recommendation.factors) { factor in
        factorRow(factor)
      }
    }
    .padding(14)
    .background(.background.secondary, in: .rect(cornerRadius: 20))
  }

  // MARK: - Header

  private var header: some View {
    HStack {
      Label("Why this one", systemImage: "text.magnifyingglass")
        .font(.footnote.weight(.semibold))

      Spacer()

      Text(recommendation.score, format: .percent.precision(.fractionLength(0)))
        .font(.footnote.weight(.semibold).monospacedDigit())
        .foregroundStyle(.secondary)
        .accessibilityLabel(
          Text(
            "Match score \(Int((recommendation.score * 100).rounded())) percent"
          ))
    }
  }

  // MARK: - Rows

  private func factorRow(_ factor: RecommendationFactor) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: icon(for: factor.kind))
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(width: 16)

      Text(factor.detail)
        .font(.caption)
        .fixedSize(horizontal: false, vertical: true)

      Spacer(minLength: 8)

      Text(impactLabel(factor.impact))
        .font(.caption2.weight(.semibold).monospacedDigit())
        .foregroundStyle(factor.isPositive ? Color.green : Color.orange)
        .accessibilityHidden(true)
    }
    .accessibilityElement(children: .combine)
  }

  private func icon(for kind: RecommendationFactor.Kind) -> String {
    switch kind {
    case .temperature: return "thermometer.medium"
    case .snowType: return "snowflake"
    case .specificity: return "scope"
    case .humidity: return "humidity"
    case .rain: return "cloud.rain"
    case .freshSnow: return "cloud.snow"
    case .abrasion: return "sparkles"
    case .warming: return "thermometer.sun"
    }
  }

  /// Renders a multiplier as a signed percentage, e.g. 1.18 → "+18%".
  private func impactLabel(_ impact: Double) -> String {
    let delta = Int(((impact - 1.0) * 100).rounded())
    if delta == 0 { return "—" }
    return delta > 0 ? "+\(delta)%" : "\(delta)%"
  }
}

#Preview {
  let product = WaxCatalog.all.first { $0.kind == .hardwax }!
  let conditions = WaxConditions(
    temperatureC: -9,
    snowType: .fineGrained,
    relativeHumidity: 0.9,
    recentRainMM: 0,
    recentSnowMM: 6,
    isSnowing: true
  )

  return VStack {
    if let recommendation = WaxRecommender.score(product, conditions: conditions) {
      RecommendationFactorsView(recommendation: recommendation)
    }
  }
  .padding()
  .background(.blue.opacity(0.3))
}
