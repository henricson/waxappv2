//
//  GanttTask.swift
//  waxappv2
//
//  Created by Herman Henriksen on 03/12/2025.
//
import Foundation
import SwiftUI

extension SwixWax {
    /// Returns a single combined range for the given snow type, if any.
    func combinedRange(for snowType: SnowType) -> TempRangeC? {
        let rs = ranges(for: snowType)
        guard !rs.isEmpty else { return nil }

        let minTemp = rs.map(\.min).min()!
        let maxTemp = rs.map(\.max).max()!
        return TempRangeC(minTemp, maxTemp)
    }
}

// MARK: - Models

struct GanttTask<ID: Hashable, T> {
    let id: ID
    let start: Int
    let end: Int
    let renderItem: T
}

struct PlacedGanttTask<ID: Hashable, T>: Identifiable {
    let id: ID
    let start: Int
    let end: Int
    let row: Int
    let renderItem: T
}

// MARK: - Generic PriorityQueue (Min-Heap)

struct PriorityQueue<Element> {
    private var elements: [Element] = []
    private let areSorted: (Element, Element) -> Bool

    init(sort: @escaping (Element, Element) -> Bool) {
        self.areSorted = sort
    }

    var isEmpty: Bool { elements.isEmpty }
    var count: Int { elements.count }

    func peek() -> Element? { elements.first }

    mutating func push(_ value: Element) {
        elements.append(value)
        siftUp(from: elements.count - 1)
    }

    mutating func pop() -> Element? {
        guard !elements.isEmpty else { return nil }
        elements.swapAt(0, elements.count - 1)
        let popped = elements.removeLast()
        if !elements.isEmpty { siftDown(from: 0) }
        return popped
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        var parent = (child - 1) / 2
        while child > 0 && areSorted(elements[child], elements[parent]) {
            elements.swapAt(child, parent)
            child = parent
            parent = (child - 1) / 2
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var candidate = parent

            if left < elements.count && areSorted(elements[left], elements[candidate]) {
                candidate = left
            }
            if right < elements.count && areSorted(elements[right], elements[candidate]) {
                candidate = right
            }
            if candidate == parent { return }
            elements.swapAt(parent, candidate)
            parent = candidate
        }
    }
}

private struct RowSlot {
    var nextFree: Int
    let rowIndex: Int
}

// MARK: - Row Assignment Algorithm

func assignRows<ID: Hashable, T>(
    tasks: [GanttTask<ID, T>],
    padding: Int = 0
) -> (placements: [PlacedGanttTask<ID, T>], rowsCount: Int) {
    let sorted = tasks.sorted {
        if $0.start == $1.start { return $0.end < $1.end }
        return $0.start < $1.start
    }

    var heap = PriorityQueue<RowSlot>(sort: { $0.nextFree < $1.nextFree })

    var rowsCount = 0
    var placed: [PlacedGanttTask<ID, T>] = []
    placed.reserveCapacity(sorted.count)

    for t in sorted {
        if let top = heap.peek(), top.nextFree + padding <= t.start {
            var slot = heap.pop()!
            placed.append(.init(id: t.id, start: t.start, end: t.end, row: slot.rowIndex, renderItem: t.renderItem))
            slot.nextFree = t.end
            heap.push(slot)
        } else {
            let rowIndex = rowsCount
            rowsCount += 1
            placed.append(.init(id: t.id, start: t.start, end: t.end, row: rowIndex, renderItem: t.renderItem))
            heap.push(RowSlot(nextFree: t.end, rowIndex: rowIndex))
        }
    }

    return (placements: placed, rowsCount: rowsCount)
}

func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double { min(max(x, a), b) }

// MARK: - View

struct Gantt: View {
    /// Temperature in °C, as stored in RecommendationStore.
    @Binding var temperature: Int
    @Binding var snowType: SnowType

    // Discrete scroll position (degree) for iOS 17 scroll APIs.
    @State private var scrollPosition: Int?
    @State private var isProgrammaticScroll: Bool = false

    @Environment(\.displayScale) private var displayScale

    let minTemp: Double = -30
    let maxTemp: Double = 30

    // Set bar and row height to match SnowTypeButtons (vertical padding 8 + font ~16 + 8 = 32, use 36 for comfort)
    let rowHeight: Double = 40
    let barHeight: Double = 20
    let chartWidth: Double = 3000

    private let axisHeight: Double = 34

    private func normalizeTemperature(_ t: Double) -> Int {
        Int(clamp(t.rounded(), minTemp, maxTemp))
    }

    private func clampedTemperature(_ t: Int) -> Int {
        normalizeTemperature(Double(t))
    }

    private func x(for temperature: Int, pxPerDegree: Double) -> CGFloat {
        let t = clamp(Double(temperature), minTemp, maxTemp)
        return CGFloat((t - minTemp) * pxPerDegree)
    }

    var body: some View {
        // The visual grid has one column per integer degree, inclusive of endpoints.
        let degreesCount = Int(maxTemp - minTemp) + 1
        let pxPerDegree: Double = chartWidth / Double(degreesCount)

        let tickXOffset: Double = pxPerDegree / 2.0
        let tickLineWidth: Double = max(1.0 / Double(displayScale), 1)

        let ganttTasks: [GanttTask<String, SwixWax>] = swixWaxes.compactMap { wax -> GanttTask<String, SwixWax>? in
            guard let r = wax.combinedRange(for: snowType) else { return nil }
            return GanttTask(
                id: wax.id,
                start: Int(Double(r.min)),
                end: Int(Double(r.max)),
                renderItem: wax
            )
        }

        let placedTasks = assignRows(tasks: ganttTasks)
        let maxRow = placedTasks.placements.map { $0.row }.max() ?? 0

        let contentHeight: Double = Double(maxRow + 1) * rowHeight + 40
        // Content width should match the scrollable degree columns exactly.
        let contentWidth: Double = Double(degreesCount) * pxPerDegree

        return GeometryReader { proxy in
            ZStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    ZStack(alignment: .topLeading) {
                        // Discrete degree markers used for snapping + scrollPosition.
                        // IMPORTANT: keep per-degree marker width == pxPerDegree so the modulus snapping aligns.
                        HStack(spacing: 0) {
                            ForEach(Int(minTemp)...Int(maxTemp), id: \.self) { degree in
                                Color.clear
                                    .frame(width: pxPerDegree, height: 1)
                                    .id(degree)
                            }
                        }
                        .scrollTargetLayout()

                        // X-axis ticks + labels (pinned at the bottom of the ZStack)
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            ZStack(alignment: .topLeading) {
                                ForEach(Int(minTemp)...Int(maxTemp), id: \.self) { degree in
                                    let x = (Double(degree) - minTemp) * pxPerDegree + tickXOffset

                                    VStack(spacing: 2) {
                                        Rectangle()
                                            .fill(.secondary.opacity(0.6))
                                            .frame(width: tickLineWidth, height: 8)

                                        Text("\(degree)°")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .fixedSize()
                                    }
                                    .position(x: x, y: axisHeight / 2)
                                }
                            }
                            .frame(height: axisHeight)
                        }

                        // Bars
                        ForEach(Array(placedTasks.placements.enumerated()), id: \.element.id) { index, task in
                            let start = clamp(Double(task.start), minTemp, maxTemp)
                            let end = clamp(Double(task.end), minTemp, maxTemp)
                            let wax = task.renderItem

                            if end > start {
                                let x = (start - minTemp) * pxPerDegree + tickXOffset
                                let width = max(1.0, (end - start) * pxPerDegree)
                                let y = Double(task.row) * rowHeight + axisHeight
                                
                                let baseColor = Color(hex: wax.primaryColor) ?? .blue
                                let secondaryColor = wax.secondaryColor.flatMap { Color(hex: $0) }

                                GanttBarView(
                                    wax: wax,
                                    baseColor: baseColor,
                                    secondaryColor: secondaryColor,
                                    barHeight: barHeight
                                )
                                .frame(width: width, height: barHeight)
                                .offset(x: x, y: y)
                                .transition(.asymmetric(
                                    insertion: .opacity
                                        .combined(with: .scale(scale: 0.9, anchor: .leading))
                                        .combined(with: .offset(x: -20)),
                                    removal: .opacity
                                        .combined(with: .scale(scale: 0.9, anchor: .trailing))
                                ))
                            }
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: snowType)
                    }
                    .frame(width: contentWidth, height: max(contentHeight + axisHeight, proxy.size.height), alignment: .topLeading)
                }
                .scrollTargetBehavior(SnapTopClosesestDegree(snapModulus: pxPerDegree, maxColumnIndex: degreesCount - 1))
                .scrollPosition(id: $scrollPosition, anchor: .center)
                .defaultScrollAnchor(.center)
                .contentMargins(.horizontal, proxy.size.width / 2, for: .scrollContent)
                .sensoryFeedback(.increase, trigger: scrollPosition)


                // Parent -> Gantt: when temperature changes externally, scroll to it.
                .onChange(of: temperature) { _, newValue in
                    let clamped = clampedTemperature(newValue)
                    guard scrollPosition != clamped else { return }
                    isProgrammaticScroll = true
                    withAnimation(.easeInOut(duration: 0.35)) {
                        scrollPosition = clamped
                    }
                    // Clear guard on next runloop so user scroll updates propagate.
                    DispatchQueue.main.async {
                        isProgrammaticScroll = false
                    }
                }

                // Gantt -> Parent: when the scroll position changes (any input), update temperature.
                .onChange(of: scrollPosition) { _, newValue in
                    guard !isProgrammaticScroll else { return }
                    guard let degree = newValue else { return }
                    let clamped = clampedTemperature(degree)
                    if clamped != temperature {
                        temperature = clamped
                    }
                }

                .onAppear {
                    scrollPosition = clampedTemperature(temperature)
                }

                Rectangle()
                    .frame(width: 1)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Snapping

struct GanttBarView: View {
    let wax: SwixWax
    let baseColor: Color
    let secondaryColor: Color?
    let barHeight: Double
    
    private var gradientColors: [Color] {
        let lighterColor = baseColor.opacity(0.93)
        let darkerColor = baseColor.opacity(0.72)
        return [lighterColor, darkerColor]
    }
    
    private var textColor: Color {
        baseColor.isLight ? .black.opacity(0.85) : .white
    }
    
    var body: some View {
        HStack(spacing: 6) {
            // Wax icon
            Group {
                if wax.kind == .klister {
                    KlisterCanView(
                        bodyColor: baseColor
                    )
                } else {
                    WaxCanGraphic(
                        bodyFill: LinearGradient(
                            colors: [baseColor, baseColor],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        showBand: secondaryColor != nil,
                        bandPrimaryColor: secondaryColor ?? baseColor,
                        bandSecondaryColor: secondaryColor
                    )
                }
            }
            .frame(width: barHeight * 0.5, height: barHeight * 0.85)
            
            // Wax name
            Text(wax.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(textColor)
                .lineLimit(1)
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    Capsule()
                        .strokeBorder(
                            baseColor.opacity(0.18),
                            lineWidth: 1
                        )
                }
        }
        .shadow(color: .black.opacity(0.10), radius: 1.5, x: 0, y: 1)
    }
}

struct SnapTopClosesestDegree: ScrollTargetBehavior {
    var snapModulus: Double
    var maxColumnIndex: Int

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard snapModulus > 0 else { return }

        // Dampen velocity for a "sticky" feel - limits how far the scroll travels
        let velocity = context.velocity.dx
        let dampingFactor: Double = 0.03
        let maxExtraColumns: Double = 0.5
        
        // Calculate how many extra columns to travel based on velocity
        let extraDistance = min(abs(velocity) * dampingFactor, maxExtraColumns * snapModulus)
        let signedExtra = velocity > 0 ? extraDistance : -extraDistance
        
        let centerX = target.rect.midX + signedExtra
        
        // Snap to center of each degree column.
        // Column centers are at: 0.5*snapModulus, 1.5*snapModulus, 2.5*snapModulus, ...
        // i.e., (N + 0.5) * snapModulus for integer N.
        // To find nearest: subtract half, round to nearest integer, add half back.
        var columnIndex = Int(((centerX - snapModulus / 2) / snapModulus).rounded())
        // Clamp to valid column range
        columnIndex = max(0, min(columnIndex, maxColumnIndex))
        let snappedCenterX = (Double(columnIndex) + 0.5) * snapModulus
        let dx = snappedCenterX - target.rect.midX

        target.rect = target.rect.offsetBy(dx: dx, dy: 0)
    }
}



#Preview {
    @Previewable @State var temperature: Int = 0
    @Previewable @State var snowType : SnowType = .fineGrained
    VStack {
        Text(String(temperature))
        Gantt(temperature: $temperature, snowType: $snowType)

    }
}
