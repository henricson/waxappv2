import SwiftUI

struct WaxSelectionView: View {
    @EnvironmentObject var store: WaxSelectionStore
    
    // Default expanded state: V-series is expanded
    @State private var expandedSeries: Set<WaxSeries> = [.V]

    var body: some View {
        List {
            ForEach(WaxSeries.allCases) { series in
                let waxes = swixWaxes.filter { $0.waxSeries == series }
                
                if !waxes.isEmpty {
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { expandedSeries.contains(series) },
                            set: { isExpanded in
                                withAnimation {
                                    if isExpanded {
                                        expandedSeries.insert(series)
                                    } else {
                                        expandedSeries.remove(series)
                                    }
                                }
                            }
                        )
                    ) {
                        ForEach(waxes) { wax in
                            WaxRow(wax: wax, isSelected: store.isSelected(wax)) {
                                store.setSelected(!store.isSelected(wax), for: wax)
                            }
                        }
                    } label: {
                        Text(series.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .navigationTitle("Select Waxes")
    }
}

struct WaxRow: View {
    let wax: SwixWax
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
                
                // Icon
                waxIcon
                    .frame(width: 30, height: 45)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(wax.code)
                        .font(.headline)
                    Text(wax.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    var waxIcon: some View {
        if wax.kind == .hardwax {
            WaxCanGraphic(
                bodyFill: AnyShapeStyle(Color(hex: wax.primaryColor) ?? .gray),
                bodyIllumination: LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                bodySpecular: LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom),
                showBand: true,
                bandPrimaryColor: Color(hex: wax.primaryColor) ?? .white,
                bandSecondaryColor: (wax.secondaryColor.flatMap { Color(hex: $0) }) ?? .blue
            )
        } else {
            KlisterCanView(bodyColor: Color(hex: wax.primaryColor) ?? .white)
        }
    }
}

#Preview {
    NavigationView {
        WaxSelectionView()
            .environmentObject(WaxSelectionStore())
    }
}
