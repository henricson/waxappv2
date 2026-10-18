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

  var body: some View {
    List {
      ForEach(WaxBrand.allCases) { brand in
        let series = WaxCatalog.series.filter {
          $0.brand == brand && domainFilter.matches($0.domain)
        }

        if !series.isEmpty {
          Section {
            ForEach(series) { s in
              seriesRow(s)
            }
          } header: {
            brandHeader(brand, series: series)
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("Wax library")
    .safeAreaInset(edge: .top) {
      filterBar
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button("Reset to defaults", systemImage: "arrow.counterclockwise") {
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

  // MARK: - Brand header

  private func brandHeader(_ brand: WaxBrand, series: [WaxSeries]) -> some View {
    HStack {
      Circle()
        .fill(Color(hex: brand.tintHex) ?? .accentColor)
        .frame(width: 8, height: 8)

      Text(brand.displayName)
        .font(.headline)
        .textCase(nil)
        .foregroundStyle(.primary)

      Spacer()

      let onCount = series.count { store.isSelected(series: $0) }
      Button(onCount == series.count ? "None" : "All") {
        withAnimation(.snappy) {
          store.setSelected(onCount != series.count, brand: brand)
        }
      }
      .font(.caption.weight(.semibold))
      .buttonStyle(.borderless)
      .textCase(nil)
    }
    .padding(.vertical, 2)
  }

  // MARK: - Series row

  @ViewBuilder
  private func seriesRow(_ series: WaxSeries) -> some View {
    let products = WaxCatalog.products(inSeries: series.id)
    let isOn = store.isSelected(series: series)
    let isExpanded = expandedSeries.contains(series.id)

    VStack(spacing: 0) {
      Toggle(
        isOn: Binding(
          get: { isOn },
          set: { newValue in
            withAnimation(.snappy) { store.setSelected(newValue, series: series) }
          }
        )
      ) {
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(series.name)
              .font(.body.weight(.medium))

            if series.isAdvanced {
              Text("Pro")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(.tint.opacity(0.15), in: Capsule())
                .foregroundStyle(.tint)
            }
          }

          Text(series.blurb)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .toggleStyle(.switch)

      if isOn {
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
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.top, 6)
        }
        .buttonStyle(.plain)
      }

      if isOn && isExpanded {
        VStack(spacing: 0) {
          ForEach(products) { product in
            productRow(product)
          }
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .padding(.vertical, 4)
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
          .frame(width: 26, height: 38)

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
