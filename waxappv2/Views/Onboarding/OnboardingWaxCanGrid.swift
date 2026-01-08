//
//  OnboardingWaxCanGrid.swift
//  waxappv2
//
//  Created by Herman Henriksen on 08/01/2026.
//
import SwiftUI

struct OnboardingWaxCanGrid: View {
    private let waxes: [SwixWax] = swixWaxes.filter { $0.kind == .hardwax || $0.kind == .klister }

    private let itemSize = CGSize(width: 30, height: 42)
    private let spacing: CGFloat = 10
    private let maxWidth: CGFloat = 420

    @State private var visibleCount: Int = 0
    @State private var animationTask: Task<Void, Never>? = nil

    // Haptics
    private let feedback = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        GeometryReader { geo in
            let availableWidth = min(geo.size.width, maxWidth)
            let columnCount = max(1, Int((availableWidth + spacing) / (itemSize.width + spacing)))

            VStack(alignment: .leading, spacing: spacing) {
                ForEach(0..<rowCount(for: waxes.count, columns: columnCount), id: \.self) { row in
                    let start = row * columnCount
                    let end = min(start + columnCount, waxes.count)
                    let itemsInRow = max(0, end - start)

                    let isLastRow = row == rowCount(for: waxes.count, columns: columnCount) - 1
                    let isPartialRow = itemsInRow < columnCount

                    HStack(spacing: spacing) {
                        if isLastRow && isPartialRow {
                            // Geometrically center the last row as a group.
                            // (Don't keep grid alignment; just center the content.)
                            Spacer(minLength: 0)
                            rowItems(start: start, end: end)
                            Spacer(minLength: 0)
                        } else {
                            rowItems(start: start, end: end)

                            // Ensure fixed row width for alignment.
                            if itemsInRow < columnCount {
                                gaps(count: columnCount - itemsInRow)
                            }
                        }
                    }
                    .frame(width: rowWidth(columns: columnCount), alignment: .leading)
                }
            }
            // Center whole grid block horizontally while keeping fill from top-left.
            .frame(width: rowWidth(columns: columnCount), alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        // Provide a stable height so the page layout doesn't move.
        .frame(height: 200)
        .onAppear {
            feedback.prepare()
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Wax overview"))
    }

    private func rowWidth(columns: Int) -> CGFloat {
        CGFloat(columns) * itemSize.width + CGFloat(max(0, columns - 1)) * spacing
    }

    @ViewBuilder
    private func gaps(count: Int) -> some View {
        ForEach(0..<max(0, count), id: \.self) { _ in
            Color.clear
                .frame(width: itemSize.width, height: itemSize.height)
        }
    }

    @ViewBuilder
    private func rowItems(start: Int, end: Int) -> some View {
        ForEach(start..<end, id: \.self) { i in
            let wax = waxes[i]
            OnboardingWaxIcon(wax: wax)
                .frame(width: itemSize.width, height: itemSize.height)
                .opacity(i < visibleCount ? 1 : 0)
                .scaleEffect(i < visibleCount ? 1 : 0.9, anchor: .center)
                .animation(.spring(response: 0.22, dampingFraction: 0.85), value: visibleCount)
        }
    }

    private func rowCount(for count: Int, columns: Int) -> Int {
        guard columns > 0 else { return 0 }
        return (count + columns - 1) / columns
    }

    private func startAnimation() {
        visibleCount = 0
        animationTask?.cancel()

        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)

            for _ in waxes.indices {
                if Task.isCancelled { return }

                visibleCount = min(visibleCount + 1, waxes.count)

                feedback.impactOccurred(intensity: 0.35)
                feedback.prepare()

                try? await Task.sleep(nanoseconds: 35_000_000)
            }
        }
    }
}


#Preview {
    OnboardingWaxCanGrid()
        .frame(maxWidth: 420)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
}
