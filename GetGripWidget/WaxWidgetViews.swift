//
//  WaxWidgetViews.swift
//  GetGripWidget
//
//  One layout per widget family. Small shows one wax unless asked for two;
//  medium and large have room for grip and glide side by side, and give a
//  single wax a proper hero with its alternatives.
//

import SwiftUI
import WidgetKit

struct WaxWidgetView: View {
  let entry: WaxEntry

  @Environment(\.widgetFamily) private var family

  var body: some View {
    content
      .containerBackground(for: .widget) { background }
      .widgetURL(entry.domains(roomForTwo: false).first.map(\.appURL))
  }

  @ViewBuilder
  private var content: some View {
    if entry.state != .ready {
      WidgetMessage(state: entry.state, family: family)
    } else {
      switch family {
      case .systemSmall: SmallWaxView(entry: entry)
      case .systemMedium: MediumWaxView(entry: entry)
      case .systemLarge, .systemExtraLarge: LargeWaxView(entry: entry)
      case .accessoryInline: InlineWaxView(entry: entry)
      case .accessoryCircular: CircularWaxView(entry: entry)
      case .accessoryRectangular: RectangularWaxView(entry: entry)
      @unknown default: SmallWaxView(entry: entry)
      }
    }
  }

  /// A faint wash of the top pick's colour, as behind the app's hero.
  private var background: some View {
    let product = entry.domains(roomForTwo: false).first.flatMap { entry.pick(for: $0)?.top?.product }
    let tint = product.flatMap { Color(hex: $0.backgroundColor) } ?? .accentColor
    return ZStack {
      Color(.systemBackground)
      LinearGradient(
        colors: [tint.opacity(0.22), tint.opacity(0.04)],
        startPoint: .top, endPoint: .bottom)
    }
  }
}

// MARK: - Building blocks

/// Domain glyph and name, like the app's Grip/Glide switch.
private struct DomainLabel: View {
  let domain: WaxDomain

  var body: some View {
    Label {
      Text(domain.title)
    } icon: {
      DomainGlyph(domain: domain)
    }
    .labelStyle(CompactLabelStyle())
    .font(.caption2.weight(.semibold))
    .foregroundStyle(.secondary)
    .lineLimit(1)
  }
}

private struct CompactLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 3) {
      configuration.icon.scaleEffect(0.8)
      configuration.title
    }
  }
}

/// Place, temperature and snow, in one quiet line.
private struct ConditionsLine: View {
  let entry: WaxEntry
  var showsSnow = true

  var body: some View {
    HStack(spacing: 4) {
      if let place = entry.placeName {
        Text(place).lineLimit(1)
      }
      Spacer(minLength: 4)
      if showsSnow, let snow = entry.snowType {
        Image(systemName: snow.iconName)
          .accessibilityLabel(snow.title)
      }
      if let temperature = entry.temperatureText {
        Text(temperature).fontWeight(.semibold).monospacedDigit()
      }
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
  }
}

/// What to show when a domain has nothing that fits.
private struct NoMatch: View {
  var body: some View {
    Text("Widget_NoMatch")
      .font(.caption2)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
  }
}

/// A row of small containers for the runners-up.
private struct AlternativesRow: View {
  let products: [WaxProduct]
  var iconHeight: CGFloat = 22

  var body: some View {
    HStack(spacing: 8) {
      ForEach(products) { product in
        HStack(spacing: 3) {
          WaxIcon(product: product)
            .frame(width: iconHeight * 0.75, height: iconHeight)
          Text(verbatim: product.code)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
        }
      }
    }
  }
}

// MARK: - Small

private struct SmallWaxView: View {
  let entry: WaxEntry

  var body: some View {
    let domains = entry.domains(roomForTwo: entry.choice == .both)

    VStack(alignment: .leading, spacing: 6) {
      ConditionsLine(entry: entry, showsSnow: domains.count == 1)

      if domains.count == 1, let domain = domains.first {
        single(domain)
      } else {
        HStack(alignment: .bottom, spacing: 8) {
          ForEach(domains, id: \.self) { domain in
            column(domain)
          }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
      }
    }
  }

  @ViewBuilder
  private func single(_ domain: WaxDomain) -> some View {
    DomainLabel(domain: domain)

    if let top = entry.pick(for: domain)?.top {
      HStack(alignment: .bottom, spacing: 8) {
        WaxIcon(product: top.product)
          .frame(width: 46, height: 76)
        VStack(alignment: .leading, spacing: 1) {
          Text(verbatim: top.product.code)
            .font(.title3.weight(.bold))
            .minimumScaleFactor(0.7)
          Text(top.product.name)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
        .lineLimit(1)
      }
      .frame(maxHeight: .infinity, alignment: .bottom)
    } else {
      NoMatch().frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func column(_ domain: WaxDomain) -> some View {
    VStack(spacing: 3) {
      if let top = entry.pick(for: domain)?.top {
        WaxIcon(product: top.product)
          .frame(height: 60)
        Text(verbatim: top.product.code)
          .font(.subheadline.weight(.bold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      } else {
        NoMatch().frame(height: 60)
      }
      DomainLabel(domain: domain)
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Medium

private struct MediumWaxView: View {
  let entry: WaxEntry

  var body: some View {
    let domains = entry.domains(roomForTwo: true)

    VStack(alignment: .leading, spacing: 8) {
      ConditionsLine(entry: entry)

      if domains.count == 1, let domain = domains.first {
        hero(domain)
      } else {
        HStack(spacing: 10) {
          ForEach(domains, id: \.self) { domain in
            Link(destination: domain.appURL) { card(domain) }
          }
        }
      }
    }
  }

  private func hero(_ domain: WaxDomain) -> some View {
    let pick = entry.pick(for: domain)
    return HStack(alignment: .bottom, spacing: 14) {
      if let top = pick?.top {
        WaxIcon(product: top.product)
          .frame(width: 70, height: 104)

        VStack(alignment: .leading, spacing: 3) {
          DomainLabel(domain: domain)
          Text(top.product.name)
            .font(.headline)
            .lineLimit(1)
          Text(verbatim: "\(top.product.code) · \(top.product.kindDisplay)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Spacer(minLength: 4)
          if let alternatives = pick?.alternatives, !alternatives.isEmpty {
            AlternativesRow(products: Array(alternatives.prefix(3)))
          }
        }
      } else {
        NoMatch().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(maxHeight: .infinity, alignment: .bottom)
  }

  /// One half of the grip-and-glide layout: its label on top, then the
  /// container standing beside the code and name.
  private func card(_ domain: WaxDomain) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      DomainLabel(domain: domain)

      if let top = entry.pick(for: domain)?.top {
        HStack(alignment: .bottom, spacing: 8) {
          WaxIcon(product: top.product)
            .frame(width: 46, height: 80)
          VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: top.product.code)
              .font(.headline.weight(.bold))
              .lineLimit(1)
              .minimumScaleFactor(0.7)
            Text(top.product.name)
              .font(.caption2)
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
      } else {
        NoMatch().frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .foregroundStyle(.primary)
  }
}

// MARK: - Large

private struct LargeWaxView: View {
  let entry: WaxEntry

  var body: some View {
    let domains = entry.domains(roomForTwo: true)

    VStack(alignment: .leading, spacing: 12) {
      ConditionsLine(entry: entry)

      ForEach(Array(domains.enumerated()), id: \.element) { index, domain in
        if index > 0 { Divider() }
        Link(destination: domain.appURL) {
          section(domain, isOnly: domains.count == 1)
        }
      }
    }
    .foregroundStyle(.primary)
  }

  private func section(_ domain: WaxDomain, isOnly: Bool) -> some View {
    let pick = entry.pick(for: domain)
    let iconHeight: CGFloat = isOnly ? 190 : 118

    return HStack(alignment: .bottom, spacing: 16) {
      if let top = pick?.top {
        WaxIcon(product: top.product)
          .frame(width: iconHeight * 0.68, height: iconHeight)

        VStack(alignment: .leading, spacing: 4) {
          DomainLabel(domain: domain)
          Text(top.product.name)
            .font(isOnly ? .title2.weight(.bold) : .headline)
            .lineLimit(2)
          Text(verbatim: "\(top.product.code) · \(top.product.kindDisplay)")
            .font(.caption)
            .foregroundStyle(.secondary)

          if let prep = pick?.preparation {
            Text("Lay down \(prep.code) first")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }

          Spacer(minLength: 6)

          if let alternatives = pick?.alternatives, !alternatives.isEmpty {
            Text("Also works")
              .font(.caption2.weight(.semibold))
              .textCase(.uppercase)
              .foregroundStyle(.secondary)
            AlternativesRow(products: alternatives, iconHeight: isOnly ? 30 : 24)
          }
        }
      } else {
        VStack(alignment: .leading) {
          DomainLabel(domain: domain)
          NoMatch().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
  }
}

// MARK: - Lock screen

private struct InlineWaxView: View {
  let entry: WaxEntry

  var body: some View {
    let codes = entry.domains(roomForTwo: entry.choice == .both)
      .compactMap { entry.pick(for: $0)?.top?.product.code }
    let parts = [codes.joined(separator: " / "), entry.temperatureText].compactMap { $0 }
    Text(verbatim: parts.joined(separator: " · "))
  }
}

private struct CircularWaxView: View {
  let entry: WaxEntry

  var body: some View {
    let domain = entry.domains(roomForTwo: false).first ?? .grip
    ZStack {
      AccessoryWidgetBackground()
      VStack(spacing: 0) {
        DomainGlyph(domain: domain)
          .frame(width: 12, height: 12)
        Text(verbatim: entry.pick(for: domain)?.top?.product.code ?? "–")
          .font(.system(.body, design: .rounded).weight(.bold))
          .minimumScaleFactor(0.5)
          .lineLimit(1)
        if let temperature = entry.temperatureText {
          Text(verbatim: temperature)
            .font(.system(size: 10, weight: .medium))
        }
      }
      .padding(4)
    }
    .widgetAccentable()
  }
}

private struct RectangularWaxView: View {
  let entry: WaxEntry

  var body: some View {
    let domains = entry.domains(roomForTwo: entry.choice == .both)

    VStack(alignment: .leading, spacing: 1) {
      ForEach(domains, id: \.self) { domain in
        HStack(spacing: 4) {
          DomainGlyph(domain: domain).frame(width: 12, height: 12)
          if let top = entry.pick(for: domain)?.top {
            Text(verbatim: top.product.code).fontWeight(.bold)
            Text(top.product.name).foregroundStyle(.secondary)
          } else {
            Text("–")
          }
        }
        .lineLimit(1)
      }
      if domains.count == 1 {
        ConditionsLine(entry: entry)
      } else if let temperature = entry.temperatureText {
        Text(verbatim: [entry.placeName, temperature].compactMap { $0 }.joined(separator: " · "))
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .font(.caption)
    .widgetAccentable()
  }
}

// MARK: - States

private struct WidgetMessage: View {
  let state: WaxEntry.State
  let family: WidgetFamily

  private var text: LocalizedStringKey {
    switch state {
    case .ready: return ""
    case .locked: return "Widget_Locked"
    case .needsPlace: return "Widget_NeedsPlace"
    case .needsLocation: return "Widget_NeedsLocation"
    case .weatherUnavailable: return "Widget_WeatherUnavailable"
    }
  }

  private var symbol: String {
    switch state {
    case .locked: return "lock.fill"
    case .needsPlace: return "mappin.and.ellipse"
    case .needsLocation: return "location.slash"
    default: return "cloud.snow"
    }
  }

  var body: some View {
    switch family {
    case .accessoryInline, .accessoryCircular, .accessoryRectangular:
      Label(text, systemImage: symbol)
        .font(.caption)
    default:
      VStack(spacing: 8) {
        Image(systemName: symbol)
          .font(.title2)
          .foregroundStyle(.secondary)
        Text(text)
          .font(.caption)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
