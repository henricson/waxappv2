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
    @State private var pendingProgrammaticTarget: Int? = nil
    @State private var scrollAnimationToken: UUID = UUID()
    @State private var temperatureDebounceTask: Task<Void, Never>? = nil

    @Environment(\.displayScale) private var displayScale

    let minTemp: Double = -30
    let maxTemp: Double = 30

    // Set bar and row height to match SnowTypeButtons (vertical padding 8 + font ~16 + 8 = 32, use 36 for comfort)
    let rowHeight: Double = 40
    let barHeight: Double = 20
    let chartWidth: Double = 3000

    private let axisHeight: Double = 80
    private let temperatureDebounceNanoseconds: UInt64 = 300_000_000 // 300ms debounce for incoming temperature updates

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

    private func animationSpec() -> Animation { .easeInOut(duration: 0.35) }

    private func driveProgrammaticScroll() {
        guard let target = pendingProgrammaticTarget else { return }
        // Start a new programmatic scroll towards the latest target.
        isProgrammaticScroll = true
        scrollAnimationToken = UUID() // new token to identify this run
        let token = scrollAnimationToken
        withAnimation(animationSpec()) {
            scrollPosition = target
        }
        // Schedule completion check after the animation duration. If a newer target arrived meanwhile, run again.
        let delay = 0.36
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            // Only continue if this is still the latest animation run.
            guard token == scrollAnimationToken else { return }
            // If during the animation a new target was set and it's different from current, animate again.
            if let latest = pendingProgrammaticTarget, latest != scrollPosition {
                // Continue chaining to the latest target.
                driveProgrammaticScroll()
            } else {
                // We reached the target; clear pending and allow user-driven updates to propagate.
                pendingProgrammaticTarget = nil
                isProgrammaticScroll = false
            }
        }
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

        GeometryReader { proxy in
            let chartContent: AnyView = {
                AnyView(
                    ZStack(alignment: .topLeading) {
                        // Discrete degree markers used for snapping + scrollPosition.
                        HStack(spacing: 0) {
                            ForEach(Int(minTemp)...Int(maxTemp), id: \.self) { degree in
                                Color.clear
                                    .frame(width: pxPerDegree, height: 1)
                                    .id(degree)
                            }
                        }
                        .scrollTargetLayout()

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
                        .padding(.top, 5)

                        // XAxisView on top so labels are always visible
                        XAxisView(minTemp: minTemp, maxTemp: maxTemp, pxPerDegree: pxPerDegree, tickXOffset: tickXOffset, tickLineWidth: tickLineWidth,axisHeight: axisHeight, centerX: (Double(clampedTemperature(scrollPosition ?? temperature)) - minTemp + 0.5) * pxPerDegree)
                            .frame(height: 50)
                    }
                    .frame(width: contentWidth, height: max(contentHeight + axisHeight, proxy.size.height), alignment: .topLeading)
                )
            }()

            ZStack {
       
                ScrollView(.horizontal, showsIndicators: false) {
                    chartContent
                }
                .scrollTargetBehavior(SnapTopClosesestDegree(snapModulus: pxPerDegree, maxColumnIndex: degreesCount - 1))
                .scrollPosition(id: $scrollPosition, anchor: .center)
                .defaultScrollAnchor(.center)
                .contentMargins(.horizontal, proxy.size.width / 2, for: .scrollContent)
                .sensoryFeedback(.increase, trigger: scrollPosition)
                // Parent -> Gantt: when temperature changes externally, scroll to it.
                .onChange(of: temperature) { _, _ in
                    // Debounce incoming temperature updates to coalesce multiple quick changes (e.g., cached value -> fresh location value).
                    temperatureDebounceTask?.cancel()
                    temperatureDebounceTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: temperatureDebounceNanoseconds)
                        // Use the latest temperature value at the end of the debounce window.
                        let target = clampedTemperature(temperature)
                        // If we're already targeting this position and no programmatic target is pending, do nothing.
                        if scrollPosition == target && pendingProgrammaticTarget == nil { return }

                        // Record the latest desired target and (re)drive programmatic scrolling.
                        pendingProgrammaticTarget = target
                        // Always drive programmatic scroll — if one is in progress it will retarget mid-flight.
                        driveProgrammaticScroll()
                    }
                }

                // Gantt -> Parent: when the scroll position changes (any input), update temperature.
                .onChange(of: scrollPosition) { _, newValue in
                    guard let degree = newValue else { return }
                    let clamped = clampedTemperature(degree)

                    if isProgrammaticScroll {
                        // During programmatic scroll, keep temperature in sync only if this is the final target.
                        if let pending = pendingProgrammaticTarget, pending == clamped {
                            if temperature != clamped { temperature = clamped }
                        }
                        return
                    }
                    // User-driven update
                    if clamped != temperature {
                        temperature = clamped
                    }
                }

                .onAppear {
                    let initial = clampedTemperature(temperature)
                    scrollPosition = initial
                    pendingProgrammaticTarget = nil
                    isProgrammaticScroll = false
                }
                .onDisappear { temperatureDebounceTask?.cancel() }
                
                TemperatureGauge(temperature: temperature)
                    .padding(.top, 10)
           
            }
    
        }
        .coordinateSpace(name: "gantt-space")
        .padding(.vertical, 20)
        .frame(maxHeight: .infinity, alignment: .top)
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

