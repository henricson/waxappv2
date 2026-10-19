//
//  StoreArtTests.swift
//  waxappv2Tests
//
//  Renders the App Store creative assets — product page header, search
//  results image and the universal image that can fill both — from the
//  app's own container artwork: every wax on a wall of shelves, coldest
//  top left to warmest bottom right.
//
//  Run just these:
//    xcodebuild test -only-testing:'waxappv2Tests/StoreArtTests'
//
//  Output goes to $PREVIEW_RENDER_DIR (pass it as TEST_RUNNER_PREVIEW_RENDER_DIR),
//  or a `waxapp-previews` folder in the temporary directory.
//

import SwiftUI
import Testing

@testable import waxappv2

@MainActor
@Suite("App Store creative assets", .serialized)
struct StoreArtTests {

  /// Apple's sizes, in points at 2x. Each is uploaded at its own size, not
  /// cropped from another, so the wall fills it with only a breathing margin.
  private struct Asset {
    let name: String
    let size: CGSize
    let safe: CGSize
    let shelves: [[String]]
  }

  /// A rhythm of tin, glide pack and tube, sweeping cold to warm.
  private static let headerLine = [
    "swix.V20", "swix.PS5", "swix.KX30", "swix.V40", "swix.PS7", "swix.KX45N", "swix.V60", "swix.PS10",
  ]

  /// Grip above, glide below, each cold to warm.
  private static let gripLine = [
    "swix.V20", "rode.P30", "swix.KX30", "swix.V40", "swix.KX45N", "swix.V50", "swix.KX65", "swix.V60",
  ]
  private static let glideLine = [
    "swix.PS5", "swix.HS6L", "swix.PS7", "swix.HS7L", "swix.PS8", "swix.HS8L", "swix.PS10",
  ]

  private static let assets = [
    Asset(
      name: "appstore-universal-5244x2950", size: CGSize(width: 2622, height: 1475),
      safe: CGSize(width: 0.84, height: 0.74), shelves: [gripLine, glideLine]),
    Asset(
      name: "appstore-header-3840x1646", size: CGSize(width: 1920, height: 823),
      safe: CGSize(width: 0.84, height: 0.70), shelves: [headerLine]),
    Asset(
      name: "appstore-search-3840x2560", size: CGSize(width: 1920, height: 1280),
      safe: CGSize(width: 0.88, height: 0.80), shelves: [gripLine, glideLine]),
  ]

  @Test("Render the header, search and universal images")
  func renderStoreArt() throws {
    for asset in Self.assets {
      let renderer = ImageRenderer(
        content: StoreArtCanvas(size: asset.size, safe: asset.safe, shelves: asset.shelves)
          .frame(width: asset.size.width, height: asset.size.height)
          .environment(\.colorScheme, .dark)
      )
      renderer.scale = 2
      renderer.isOpaque = true

      let image = try #require(renderer.uiImage)
      let data = try #require(image.pngData())
      let url = PreviewRenderTests.outputDirectory.appendingPathComponent("\(asset.name).png")
      try data.write(to: url)
      print("rendered \(url.path)")
    }
  }
}

// MARK: - Canvas

/// The wall on its backdrop, centred in the canvas.
struct StoreArtCanvas: View {
  let size: CGSize
  let safe: CGSize
  let shelves: [[String]]

  var body: some View {
    ZStack {
      StoreArtBackdrop()
      WaxWall(box: CGSize(width: size.width * safe.width, height: size.height * safe.height), shelves: shelves)
    }
    .frame(width: size.width, height: size.height)
    .clipped()
  }
}

/// Deep winter-night blue with a soft light behind the shelves, darker
/// corners and the faint mountain ridges of the paywall, so the eye lands
/// in the middle.
private struct StoreArtBackdrop: View {
  var body: some View {
    GeometryReader { geo in
      let side = max(geo.size.width, geo.size.height)
      ZStack(alignment: .bottom) {
        LinearGradient(
          colors: [Color(red: 0.05, green: 0.12, blue: 0.27), Color(red: 0.10, green: 0.25, blue: 0.50)],
          startPoint: .top, endPoint: .bottom)
        RadialGradient(
          colors: [Color(red: 0.30, green: 0.52, blue: 0.86).opacity(0.45), .clear],
          center: .center, startRadius: 0, endRadius: side * 0.5)
        SwixRidge(top: 0.30, depth: 0.25, isBackdrop: true)
          .fill(.white.opacity(0.035))
          .frame(height: geo.size.height * 0.55)
        SwixRidge(top: 0.45, depth: 0.25)
          .fill(.white.opacity(0.05))
          .frame(height: geo.size.height * 0.42)
        RadialGradient(
          colors: [.clear, .black.opacity(0.45)],
          center: .center, startRadius: side * 0.35, endRadius: side * 0.8)
      }
    }
  }
}

// MARK: - Wall

/// A few chosen containers on glass shelves, big enough to read on a
/// phone, each shelf sweeping cold to warm.
struct WaxWall: View {
  let box: CGSize
  /// Product ids on each shelf, left to right.
  let shelves: [[String]]

  /// Gap between containers and between shelves, as fractions of the
  /// shelf height.
  private static let itemGap: CGFloat = 0.16
  private static let shelfGap: CGFloat = 0.42

  private static func unitWidth(_ product: WaxProduct) -> CGFloat {
    WaxIcon.shelfHeight(for: product) * WaxIcon.aspect(for: product)
  }

  private static func rowWidth(_ row: [WaxProduct]) -> CGFloat {
    row.reduce(0) { $0 + unitWidth($1) } + itemGap * CGFloat(max(row.count - 1, 0))
  }

  private var rows: [[WaxProduct]] {
    shelves.map { $0.compactMap(WaxCatalog.product(withID:)) }
  }

  var body: some View {
    let rows = self.rows
    let widest = rows.map(Self.rowWidth).max() ?? 1
    let count = CGFloat(rows.count)
    let height = min(box.width / widest, box.height / (count + Self.shelfGap * (count - 1)))
    let fullWidth = widest * height

    VStack(spacing: height * Self.shelfGap) {
      ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
        // Full shelves are spread to a common width; a shelf with much
        // less on it keeps the usual spacing and sits centred, like the
        // last line of a centred paragraph.
        let natural = Self.rowWidth(row) * height
        let isShort = natural < fullWidth * 0.75
        Shelf(
          products: row, height: height,
          width: isShort ? natural : fullWidth,
          ledgeWidth: fullWidth)
      }
    }
  }
}

/// One shelf: containers standing on a glassy ledge, spread to the wall's
/// full width so every shelf ends at the same place.
private struct Shelf: View {
  let products: [WaxProduct]
  let height: CGFloat
  let width: CGFloat
  var ledgeWidth: CGFloat? = nil

  var body: some View {
    ZStack(alignment: .bottom) {
      ledge
        .offset(y: height * 0.045)

      HStack(alignment: .bottom, spacing: 0) {
        ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
          if index > 0 { Spacer(minLength: 0) }
          let itemHeight = height * WaxIcon.shelfHeight(for: product)
          WaxIcon(product: product)
            .frame(width: itemHeight * WaxIcon.aspect(for: product), height: itemHeight)
            .shadow(color: .black.opacity(0.5), radius: height * 0.05, y: height * 0.025)
            .background(alignment: .bottom) { reflection(of: product, height: itemHeight) }
        }
      }
      .frame(width: width, height: height, alignment: .bottom)
    }
  }

  /// The container mirrored in the glass, fading out a short way down.
  private func reflection(of product: WaxProduct, height itemHeight: CGFloat) -> some View {
    WaxIcon(product: product)
      .frame(width: itemHeight * WaxIcon.aspect(for: product), height: itemHeight)
      .scaleEffect(x: 1, y: -1)
      .opacity(0.16)
      .mask {
        LinearGradient(
          colors: [.black, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.26))
      }
      .offset(y: itemHeight + height * 0.045)
  }

  private var ledge: some View {
    let thickness = height * 0.05
    return ZStack(alignment: .top) {
      Capsule()
        .fill(
          LinearGradient(
            colors: [.white.opacity(0.20), .white.opacity(0.04)],
            startPoint: .top, endPoint: .bottom))
      Capsule()
        .fill(.white.opacity(0.35))
        .frame(height: max(1, thickness * 0.12))
    }
    .frame(width: (ledgeWidth ?? width) + height * 0.4, height: thickness)
    .shadow(color: .black.opacity(0.4), radius: height * 0.06, y: height * 0.04)
  }
}
