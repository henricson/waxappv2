//
//  PreviewRenderTests.swift
//  waxappv2Tests
//
//  Renders app artwork to PNG so it can be eyeballed outside the simulator,
//  and so the App Store icon sheet can be generated from the same source of
//  truth as the app itself.
//
//  Run just these:
//    xcodebuild test -only-testing:waxappv2Tests/PreviewRenderTests
//
//  Output goes to $PREVIEW_RENDER_DIR, or a `waxapp-previews` folder in the
//  temporary directory when that is unset.
//

import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import waxappv2

#if canImport(UIKit)
  import UIKit
#endif

@MainActor
@Suite("Preview rendering", .serialized)
struct PreviewRenderTests {

  // MARK: - Output

  static var outputDirectory: URL {
    let base =
      ProcessInfo.processInfo.environment["PREVIEW_RENDER_DIR"]
      ?? NSTemporaryDirectory().appending("waxapp-previews")
    let url = URL(fileURLWithPath: base, isDirectory: true)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @discardableResult
  private func render(
    _ name: String,
    size: CGSize,
    scale: CGFloat = 2,
    colorScheme: ColorScheme = .light,
    @ViewBuilder content: () -> some View
  ) -> URL? {
    let renderer = ImageRenderer(
      content:
        content()
        .frame(width: size.width, height: size.height)
        .environment(\.colorScheme, colorScheme)
    )
    renderer.scale = scale
    renderer.isOpaque = false

    guard let image = renderer.uiImage, let data = image.pngData() else {
      Issue.record("Could not render \(name)")
      return nil
    }

    let url = Self.outputDirectory.appendingPathComponent("\(name).png")
    do {
      try data.write(to: url)
      print("rendered \(url.path)")
      return url
    } catch {
      Issue.record("Could not write \(name): \(error)")
      return nil
    }
  }

  // MARK: - Container artwork

  @Test("Render one of every container kind")
  func renderContainers() {
    let samples: [(String, WaxProduct)] = WaxKind.allCases.compactMap { kind in
      guard let product = WaxCatalog.all.first(where: { $0.kind == kind }) else { return nil }
      return (kind.rawValue, product)
    }

    for (name, product) in samples {
      render("container-\(name)", size: CGSize(width: 160, height: 240)) {
        ZStack {
          Color(white: 0.93)
          WaxIcon(product: product).padding(20)
        }
      }
    }

    render("containers-row", size: CGSize(width: 1200, height: 420)) {
      ZStack {
        Color(white: 0.95)
        HStack(spacing: 24) {
          ForEach(samples.map(\.1)) { product in
            VStack(spacing: 8) {
              WaxIcon(product: product)
                .frame(height: 290)
              Text(product.code).font(.caption)
              Text(product.kindDisplay).font(.caption2).foregroundStyle(.secondary)
            }
          }
        }
        .padding(24)
      }
    }
  }

  @Test("Render the klister tube on its own, light and dark")
  func renderKlister() {
    let klisters = WaxCatalog.all.filter { $0.kind == .klister }.prefix(6)

    for scheme in [ColorScheme.light, .dark] {
      render(
        "klister-row-\(scheme == .light ? "light" : "dark")",
        size: CGSize(width: 1200, height: 420),
        colorScheme: scheme
      ) {
        ZStack {
          (scheme == .light ? Color(white: 0.95) : Color(white: 0.10))
          HStack(spacing: 22) {
            ForEach(Array(klisters)) { product in
              VStack(spacing: 8) {
                WaxIcon(product: product).frame(height: 300)
                Text(product.code).font(.caption2)
              }
            }
          }
          .padding(24)
        }
      }
    }
  }

  // MARK: - Full catalogue sheet

  @Test("Render the full catalogue grid used for the App Store header")
  func renderCatalogueGrid() {
    let products = WaxCatalog.all
    let columns = 14

    let itemHeight: CGFloat = 92
    let spacing: CGFloat = 14
    let rows = (products.count + columns - 1) / columns
    let cellHeight = itemHeight + 5 + itemHeight * 0.17
    let height = CGFloat(rows) * cellHeight + CGFloat(rows - 1) * spacing + spacing * 4

    render(
      "catalogue-grid",
      size: CGSize(width: 1400, height: height),
      scale: 2
    ) {
      ZStack {
        Color(white: 0.97)
        CatalogueGrid(products: products, columns: columns)
      }
    }
  }
}

// MARK: - Catalogue grid

/// Every container the app can draw, laid out as a dense sheet.
/// Used both as a visual regression target and as the App Store header art.
struct CatalogueGrid: View {
  let products: [WaxProduct]
  var columns: Int = 14
  var itemHeight: CGFloat = 92
  var spacing: CGFloat = 14
  var showsCaptions: Bool = true

  var body: some View {
    let rows = products.chunked(into: columns)

    VStack(spacing: spacing) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        HStack(alignment: .top, spacing: spacing) {
          ForEach(row) { product in
            cell(product)
          }
          if row.count < columns {
            ForEach(0..<(columns - row.count), id: \.self) { _ in
              Color.clear.frame(width: itemHeight * 2 / 3)
            }
          }
        }
      }
    }
    .padding(spacing * 2)
  }

  private func cell(_ product: WaxProduct) -> some View {
    VStack(spacing: 5) {
      WaxIcon(product: product)
        .frame(width: itemHeight * 2 / 3, height: itemHeight)

      if showsCaptions {
        Text(product.code)
          .font(.system(size: itemHeight * 0.12, weight: .semibold, design: .rounded))
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .foregroundStyle(.primary)
      }
    }
    .frame(width: itemHeight * 2 / 3)
  }
}

extension Array {
  func chunked(into size: Int) -> [[Element]] {
    guard size > 0 else { return [self] }
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0..<Swift.min($0 + size, count)])
    }
  }
}
