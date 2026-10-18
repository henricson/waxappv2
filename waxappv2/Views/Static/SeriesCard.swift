//
//  SeriesCard.swift
//  waxappv2
//
//  A wax line shown as its own products: used by onboarding's picker and
//  by the wax library, so both look and behave the same.
//

import SwiftUI

/// A few products from a series, fanned like a hand of cards.
struct SeriesArt: View {
  let series: WaxSeries

  private var products: [WaxProduct] {
    let all = WaxCatalog.products(inSeries: series.id).filter { !$0.kind.isPreparation }
    guard all.count > 3 else { return all }
    // First, middle and last grade: the spread of colours in the range.
    return [all[0], all[all.count / 2], all[all.count - 1]]
  }

  var body: some View {
    let height: CGFloat = 54
    ZStack(alignment: .bottom) {
      ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
        let offset = CGFloat(index) - CGFloat(products.count - 1) / 2
        WaxIcon(product: product)
          .frame(width: height * WaxIcon.aspect(for: product), height: height)
          .offset(x: offset * 15)
          .zIndex(Double(products.count - index))
      }
    }
    .frame(width: 72, height: height + 4, alignment: .bottom)
    .accessibilityHidden(true)
  }
}

/// A wax line as a card: its products fanned on the left, name, brand and
/// blurb, and a tick. Tapping anywhere toggles the line. `footer` sits inside
/// the card below the row, for the library's per-product list.
struct SeriesToggleCard<Footer: View>: View {
  @Environment(WaxSelectionStore.self) private var store
  let series: WaxSeries
  @ViewBuilder var footer: Footer

  private var isOn: Bool { store.isSelected(series: series) }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      toggleRow
      footer
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    // A plain grouped card, like Settings. Selection is carried by the tick
    // and the artwork alone; tinting and outlining every card on top of
    // that turned a list of choices into a wall of highlights.
    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16, style: .continuous))
  }

  /// "SWIX" or "RODE · RACE": the brand and tier as a quiet label above the
  /// name, the way a shop shelf label reads.
  private var eyebrow: String {
    let brand = series.brand.displayName.uppercased()
    guard series.isAdvanced else { return brand }
    return "\(brand) · \(String(localized: "Series_Race_Tag").uppercased())"
  }

  private var toggleRow: some View {
    Button {
      withAnimation(.smooth(duration: 0.25)) {
        store.toggle(series: series)
      }
    } label: {
      HStack(spacing: 12) {
        SeriesArt(series: series)
          .saturation(isOn ? 1 : 0)
          .opacity(isOn ? 1 : 0.45)

        VStack(alignment: .leading, spacing: 2) {
          Text(verbatim: eyebrow)
            .font(.caption2.weight(.semibold))
            .kerning(0.6)
            .foregroundStyle(.secondary)

          Text(series.name)
            .font(.body.weight(.semibold))
            .foregroundStyle(.primary)

          Text(series.blurb)
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)

        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
          .contentTransition(.symbolEffect(.replace))
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isOn ? [.isSelected] : [])
    .accessibilityIdentifier("series_\(series.id)")
  }
}

extension SeriesToggleCard where Footer == EmptyView {
  init(series: WaxSeries) {
    self.init(series: series) { EmptyView() }
  }
}
