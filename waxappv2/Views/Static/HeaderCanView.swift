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
  /// The base to lay down first, shown as the step before this wax.
  var preparation: PreparationAdvice? = nil

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

      // The slot is always there, so the artwork above keeps its size
      // whether or not a base layer is advised.
      ZStack {
        if let preparation {
          PreparationStep(advice: preparation)
            .transition(.opacity)
        }
      }
      .frame(height: 50)
      .padding(.top, 6)
      .animation(.smooth(duration: 0.25), value: preparation)
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

// MARK: - Preparation step

/// The layer that goes on before the recommended wax: the user's own base
/// product with its container, or the kind of base to get.
private struct PreparationStep: View {
  let advice: PreparationAdvice

  var body: some View {
    HStack(spacing: 10) {
      if let product = advice.product {
        WaxIcon(product: product)
          .frame(width: 18, height: 28)
      } else {
        Image(systemName: "square.stack.3d.down.forward")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(width: 18)
      }

      VStack(alignment: .leading, spacing: 1) {
        Text(advice.title)
          .font(.footnote.weight(.semibold))
        Text(advice.detail)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 7)
    .frame(maxWidth: 360)
    .background(.background.secondary.opacity(0.8), in: .rect(cornerRadius: 14, style: .continuous))
    .accessibilityElement(children: .combine)
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
