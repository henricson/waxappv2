//
//  DomainGlyph.swift
//  waxappv2
//
//  Small monochrome glyphs for grip and glide, drawn as the products
//  themselves: a wax tin with its diagonal band, and a glide pack with its
//  hang tab and mountain ridge. They take the current foreground style, so
//  they tint like SF Symbols next to a label.
//

import SwiftUI

/// Grip: a snap-lid tin with the band rising across it.
nonisolated struct GripGlyphShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addRoundedRect(
      in: CGRect(origin: rect.unit(0.20, 0.08), size: CGSize(width: 0.60 * rect.width, height: 0.20 * rect.height)),
      cornerSize: CGSize(width: 0.07 * rect.width, height: 0.07 * rect.width),
      style: .continuous)
    path.addRoundedRect(
      in: CGRect(origin: rect.unit(0.25, 0.33), size: CGSize(width: 0.50 * rect.width, height: 0.60 * rect.height)),
      cornerSize: CGSize(width: 0.06 * rect.width, height: 0.06 * rect.width),
      style: .continuous)
    return path
  }
}

/// Glide: a clamshell pack with its hang tab.
nonisolated struct GlideGlyphShape: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.unit(0.32, 0.17))
    path.addLine(to: rect.unit(0.37, 0.04))
    path.addLine(to: rect.unit(0.63, 0.04))
    path.addLine(to: rect.unit(0.68, 0.17))
    path.closeSubpath()
    path.addRoundedRect(
      in: CGRect(origin: rect.unit(0.22, 0.14), size: CGSize(width: 0.56 * rect.width, height: 0.82 * rect.height)),
      cornerSize: CGSize(width: 0.08 * rect.width, height: 0.08 * rect.width),
      style: .continuous)
    return path
  }
}

/// The cut-outs: the band across the tin, the ridge and slot on the pack.
nonisolated struct DomainGlyphCut: Shape {
  var domain: WaxDomain

  func path(in rect: CGRect) -> Path {
    var path = Path()
    switch domain {
    case .grip:
      path.move(to: rect.unit(0.25, 0.80))
      path.addLine(to: rect.unit(0.75, 0.52))
      path.addLine(to: rect.unit(0.75, 0.63))
      path.addLine(to: rect.unit(0.25, 0.91))
      path.closeSubpath()
      // Lid seam.
      path.addRect(CGRect(origin: rect.unit(0.20, 0.28), size: CGSize(width: 0.60 * rect.width, height: 0.05 * rect.height)))
    case .glide:
      path.addRoundedRect(
        in: CGRect(origin: rect.unit(0.43, 0.08), size: CGSize(width: 0.14 * rect.width, height: 0.05 * rect.height)),
        cornerSize: CGSize(width: 0.025 * rect.width, height: 0.025 * rect.width))
      var ridge = Path()
      ridge.move(to: rect.unit(0.22, 0.66))
      ridge.addLine(to: rect.unit(0.36, 0.56))
      ridge.addLine(to: rect.unit(0.44, 0.62))
      ridge.addLine(to: rect.unit(0.56, 0.48))
      ridge.addLine(to: rect.unit(0.66, 0.60))
      ridge.addLine(to: rect.unit(0.78, 0.54))
      path.addPath(ridge.strokedPath(StrokeStyle(lineWidth: 0.07 * rect.width, lineJoin: .round)))
    }
    return path
  }
}

/// Silhouette minus cut-outs, as one plain shape so it tints exactly like
/// text — a blend-mode cut picks up glass vibrancy and renders grey.
nonisolated struct DomainGlyphShape: Shape {
  var domain: WaxDomain

  func path(in rect: CGRect) -> Path {
    let base =
      switch domain {
      case .grip: GripGlyphShape().path(in: rect)
      case .glide: GlideGlyphShape().path(in: rect)
      }
    return base.subtracting(DomainGlyphCut(domain: domain).path(in: rect))
  }
}

struct DomainGlyph: View {
  var domain: WaxDomain
  /// Set when the glyph must match a label's text exactly; a Label dims a
  /// custom icon view's inherited foreground on some backgrounds.
  var color: Color? = nil

  @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 18

  var body: some View {
    DomainGlyphShape(domain: domain)
      .fill(color.map(AnyShapeStyle.init) ?? AnyShapeStyle(.foreground))
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}

#Preview {
  HStack(spacing: 24) {
    Label { Text("Grip") } icon: { DomainGlyph(domain: .grip) }
    Label { Text("Glide") } icon: { DomainGlyph(domain: .glide) }
      .foregroundStyle(.white)
      .padding(8)
      .background(.purple, in: .capsule)
  }
  .font(.subheadline.weight(.semibold))
  .padding()
}
