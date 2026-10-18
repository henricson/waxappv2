//
//  WaxArtCatalogue.swift
//  waxappv2
//
//  Debug-only sheet of every product illustration, grouped by series, for
//  checking the artwork side by side. Launch with `-GGDemoCatalogue YES`.
//

#if DEBUG
  import SwiftUI

  struct WaxArtCatalogue: View {
    var domain: WaxDomain?
    /// Hero-sized artwork, where print and fine detail switch on.
    var isLarge = false

    private var groups: [(series: WaxSeries, products: [WaxProduct])] {
      WaxCatalog.series
        .filter { domain == nil || $0.domain == domain }
        .map { ($0, WaxCatalog.products(inSeries: $0.id)) }
        .filter { !$0.products.isEmpty }
    }

    var body: some View {
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          ForEach(groups, id: \.series.id) { group in
            Text(verbatim: "\(group.series.brand.displayName) \(group.series.code)")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: isLarge ? 3 : 6), spacing: 8) {
              ForEach(isLarge ? Array(group.products.prefix(3)) : group.products) { product in
                VStack(spacing: 2) {
                  WaxIcon(product: product)
                    .frame(height: isLarge ? 170 : 78)
                  Text(verbatim: product.code)
                    .font(.system(size: 9, weight: .medium))
                }
              }
            }
          }
        }
        .padding()
      }
      .background(Color(.systemGroupedBackground))
    }
  }

  extension DemoMode {
    static var showsArtCatalogue: Bool {
      isEnabled && UserDefaults.standard.bool(forKey: "GGDemoCatalogue")
    }

    static var artCatalogueIsLarge: Bool {
      UserDefaults.standard.bool(forKey: "GGDemoCatalogueLarge")
    }
  }

  #Preview {
    WaxArtCatalogue()
  }
#endif
