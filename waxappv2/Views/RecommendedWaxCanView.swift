import SwiftUI

struct RecommendedWaxCanView: View {
    let wax: SwixWax

    var body: some View {
        VStack(spacing: 8) {
            WaxCanGraphic(
                // Use defaults for topFill and middleFill to keep the lid white/metallic
                bodyFill: AnyShapeStyle(primaryColor),
                bodyIllumination: LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                bodySpecular: LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom),
                showBand: true,
                bandPrimaryColor: bandPrimaryColor,
                bandSecondaryColor: secondaryColor
            )
            .frame(height: 140)

            VStack(spacing: 2) {
                Text("\(wax.code) \(wax.name)")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text("\(wax.series) • \(wax.kindDisplay)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(wax.code) \(wax.name), \(wax.series), \(wax.kindDisplay)")
    }

    // MARK: - Colors

    private var primaryColor: Color {
        Color(hex: wax.primaryColor) ?? .gray
    }

    private var secondaryColor: Color? {
        guard let hex = wax.secondaryColor else { return nil }
        return Color(hex: hex)
    }

    // Primary band color is derived from wax kind (keeps quick visual taxonomy)
    private var bandPrimaryColor: Color {
        switch wax.kind {
        case .hardwax: return .blue
        case .klister: return .orange
        case .base: return .gray
        }
    }
}
