//
//  HeaderCanView.swift
//  waxappv2
//
//  The hero: one large, well-lit container for the wax or glider of the day.
//

import SwiftUI

struct HeaderCanView: View {
  let recommendation: WaxRecommendation
  var showsConfidence: Bool = true

  @Environment(\.colorScheme) private var colorScheme

  private var product: WaxProduct { recommendation.product }

  /// The page behind the hero is a neutral grouped background with only a
  /// faint wash of the wax colour, so the caption uses the semantic text
  /// colours rather than contrasting against the product colour.
  private var onBackground: Color { .primary }

  var body: some View {
    VStack(spacing: 0) {
      artwork
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)

      caption
        .padding(.top, 12)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(
      Text("\(product.name), \(product.code), \(product.kindDisplay)")
    )
  }

  // MARK: - Artwork

  /// Every container is drawn at its real proportions and stands on the
  /// bottom edge, so a tube, a tin and a glide pack share one baseline.
  private var artwork: some View {
    WaxIcon(product: product)
      .shadow(color: .black.opacity(0.18), radius: 10, y: 6)
  }

  // MARK: - Caption

  private var caption: some View {
    VStack(spacing: 6) {
      Text(product.name)
        .font(.title3.weight(.semibold))
        .multilineTextAlignment(.center)
        .foregroundStyle(onBackground)

      HStack(spacing: 6) {
        Text(product.code)
          .fontWeight(.medium)

        Text(verbatim: "•")

        Text(product.kindDisplay)

        if product.brand != .swix {
          Text(verbatim: "•")
          Text(product.brand.displayName)
        }
      }
      .font(.caption)
      .foregroundStyle(onBackground.opacity(0.75))

      if showsConfidence {
        confidenceBadge
      }
    }
    .padding(.horizontal, 20)
  }

  @ViewBuilder
  private var confidenceBadge: some View {
    let isConfident = recommendation.score >= WaxRecommender.confidentThreshold

    Label {
      Text(isConfident ? "Strong match" : "Closest match")
    } icon: {
      Image(systemName: isConfident ? "checkmark.seal.fill" : "questionmark.circle")
    }
    .font(.caption2.weight(.semibold))
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .glassEffect(.regular, in: .capsule)
    .foregroundStyle(onBackground)
    .padding(.top, 2)
  }
}

// MARK: - Previews

#Preview("Hard wax") {
  let product = WaxCatalog.all.first { $0.kind == .hardwax }!
  HeaderCanView(
    recommendation: WaxRecommendation(
      product: product, score: 0.92,
      matchedRange: TempRangeC(-15, -8), factors: []
    )
  )
  .frame(height: 260)
  .padding()
}

#Preview("Klister") {
  let product = WaxCatalog.all.first { $0.kind == .klister }!
  HeaderCanView(
    recommendation: WaxRecommendation(
      product: product, score: 0.48,
      matchedRange: TempRangeC(-5, 3), factors: []
    )
  )
  .frame(height: 260)
  .padding()
}

#Preview("Glider") {
  let product = WaxCatalog.all.first { $0.kind == .glideHot }!
  HeaderCanView(
    recommendation: WaxRecommendation(
      product: product, score: 0.88,
      matchedRange: TempRangeC(-12, -6), factors: []
    )
  )
  .frame(height: 260)
  .padding()
}
