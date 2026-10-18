import SwiftUI

/// Full wax library. Users turn whole series on and off, and can drill into a
/// series to hide individual products.
struct WaxSelectionView: View {
  @Environment(WaxSelectionStore.self) private var store

  @State private var expandedSeries: Set<String> = []
  @State private var domainFilter: DomainFilter = .all

  private enum DomainFilter: Hashable, CaseIterable {
    case all
    case grip
    case glide

    var title: String {
      switch self {
      case .all: return String(localized: "Filter_All")
      case .grip: return WaxDomain.grip.title
      case .glide: return WaxDomain.glide.title
      }
    }

    func matches(_ domain: WaxDomain) -> Bool {
      switch self {
      case .all: return true
      case .grip: return domain == .grip
      case .glide: return domain == .glide
      }
    }
  }

  private let region = RegionalWaxKit.Region.current

  /// The lines most skiers in the user's region carry come first; every
  /// other line — specialist brands and race wax — follows.
  private var groups: [(title: String, series: [WaxSeries])] {
    let kit = RegionalWaxKit.seriesIDs(for: region)
    let visible = WaxCatalog.series
      .filter { domainFilter.matches($0.domain) }
      .sorted { ($0.domain == .grip ? 0 : 1) < ($1.domain == .grip ? 0 : 1) }

    let common = visible.filter { kit.contains($0.id) }
    let more = visible.filter { !kit.contains($0.id) }
      .sorted { !$0.isAdvanced && $1.isAdvanced }

    let commonTitle =
      RegionalWaxKit.countryName(for: region).map { String(localized: "Popular in \($0)") }
      ?? String(localized: "Everyday lines")
    return [
      (commonTitle, common),
      (String(localized: "More wax lines"), more),
    ].filter { !$0.series.isEmpty }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 10) {
        ForEach(groups, id: \.title) { group in
          Text(group.title)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .padding(.top, 14)
            .padding(.leading, 4)
            .accessibilityAddTraits(.isHeader)

          ForEach(group.series) { series in
            SeriesToggleCard(series: series) {
              productList(for: series)
            }
          }
        }
      }
      .padding(.horizontal)
      .padding(.bottom, 24)
      .frame(maxWidth: 760)
      .frame(maxWidth: .infinity)
    }
    .background(Color(.systemGroupedBackground))
    .navigationTitle("Wax library")
    .safeAreaInset(edge: .top) {
      filterBar
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Use the recommended kit", systemImage: "arrow.counterclockwise") {
            withAnimation { store.resetToDefaults() }
          }
        } label: {
          Image(systemName: "ellipsis")
        }
      }
    }
  }

  // MARK: - Filter

  private var filterBar: some View {
    Picker("Filter", selection: $domainFilter.animation(.snappy)) {
      ForEach(DomainFilter.allCases, id: \.self) { filter in
        Text(filter.title).tag(filter)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal)
    .padding(.bottom, 8)
    .background(.bar)
  }

  // MARK: - Products in a line

  /// "6 of 8 shown", expanding to every grade in the line, each with its own
  /// container so it is recognisable at a glance.
  @ViewBuilder
  private func productList(for series: WaxSeries) -> some View {
    let products = WaxCatalog.products(inSeries: series.id)
    let isExpanded = expandedSeries.contains(series.id)

    if store.isSelected(series: series) {
      Button {
        withAnimation(.snappy) {
          if isExpanded {
            expandedSeries.remove(series.id)
          } else {
            expandedSeries.insert(series.id)
          }
        }
      } label: {
        HStack(spacing: 4) {
          let shown = products.count { store.isSelected($0) }
          Text("\(shown) of \(products.count) shown")
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
        .padding(.leading, 84)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      if isExpanded {
        VStack(spacing: 2) {
          ForEach(products) { product in
            productRow(product)
          }
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  // MARK: - Product row

  private func productRow(_ product: WaxProduct) -> some View {
    let isSelected = store.isSelected(product)

    return Button {
      withAnimation(.snappy) {
        store.setSelected(!isSelected, for: product)
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
          .contentTransition(.symbolEffect(.replace))

        WaxIcon(product: product)
          .frame(width: 34, height: 48)

        VStack(alignment: .leading, spacing: 1) {
          Text(product.code)
            .font(.subheadline.weight(.semibold))
          Text(product.name)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        Text(product.kindDisplay)
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 5)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}

#Preview {
  NavigationStack {
    WaxSelectionView()
      .environment(WaxSelectionStore())
  }
}
