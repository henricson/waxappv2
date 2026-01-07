import SwiftUI

struct WaxSelectionView: View {
    @EnvironmentObject private var waxSelection: WaxSelectionStore

    private let seriesOrder: [WaxSeries] = [.V, .VP, .K, .KX, .KN, .other]

    var body: some View {
        List {
            Section {
                Button {
                    waxSelection.resetToAllSelected()
                } label: {
                    Label("Reset to all viewed", systemImage: "arrow.counterclockwise")
                }
            }

            ForEach(seriesOrder) { series in
                let waxesInSeries = swixWaxes
                    .filter { $0.waxSeries == series }
                    .sorted { $0.code < $1.code }

                if !waxesInSeries.isEmpty {
                    Section {
                        seriesToggleRow(series: series, waxesInSeries: waxesInSeries)

                        ForEach(waxesInSeries) { wax in
                            Toggle(isOn: Binding(
                                get: { waxSelection.isSelected(wax) },
                                set: { waxSelection.setSelected($0, for: wax) }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(wax.code) \(wax.name)")
                                    Text(wax.kindDisplay)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text(series.title)
                    }
                }
            }
        }
        .navigationTitle("Visible waxes")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func seriesToggleRow(series: WaxSeries, waxesInSeries: [SwixWax]) -> some View {
        let state = waxSelection.selectionState(for: series)
        let isOn = (state == .all)

        Toggle(isOn: Binding(
            get: { isOn },
            set: { waxSelection.setAllSelected($0, in: series) }
        )) {
            HStack {
                Text("All \(series.title)")
                Spacer()
                if state == .some {
                    Text("Some")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WaxSelectionView()
            .environmentObject(WaxSelectionStore())
    }
}
