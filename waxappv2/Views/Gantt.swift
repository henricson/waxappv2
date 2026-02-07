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
      placed.append(
        .init(id: t.id, start: t.start, end: t.end, row: slot.rowIndex, renderItem: t.renderItem))
      slot.nextFree = t.end
      heap.push(slot)
    } else {
      let rowIndex = rowsCount
      rowsCount += 1
      placed.append(
        .init(id: t.id, start: t.start, end: t.end, row: rowIndex, renderItem: t.renderItem))
      heap.push(RowSlot(nextFree: t.end, rowIndex: rowIndex))
    }
  }

  return (placements: placed, rowsCount: rowsCount)
}

func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double { min(max(x, a), b) }

// MARK: - Layout Constants

private enum GanttLayoutConstants {
  static let minTemp: Double = -30
  static let maxTemp: Double = 30
  static let rowHeight: Double = 40
  static let barHeight: Double = 20
  static let chartWidth: Double = 3000
  static let axisHeight: Double = 80
  static let barsTopPadding: Double = 5
  static let temperatureDebounceNanoseconds: UInt64 = 300_000_000

  static var degreesCount: Int {
    Int(maxTemp - minTemp) + 1
  }

  static var pxPerDegree: Double {
    chartWidth / Double(degreesCount)
  }

  static var tickXOffset: Double {
    pxPerDegree / 2.0
  }

  static var contentWidth: Double {
    Double(degreesCount) * pxPerDegree
  }

  static func contentHeight(forRowCount rowCount: Int) -> Double {
    Double(rowCount) * rowHeight + axisHeight + barsTopPadding
  }
}

// MARK: - View

struct Gantt: View {
  @Environment(RecommendationStore.self) private var recStore
  @Environment(\.displayScale) private var displayScale

  let selectedWaxes: [SwixWax]

  @State private var scrollPosition: Int?
  @State private var isProgrammaticScroll = false
  @State private var pendingProgrammaticTarget: Int?
  @State private var scrollAnimationToken = UUID()
  @State private var temperatureDebounceTask: Task<Void, Never>?

  private typealias Layout = GanttLayoutConstants

  private var temperature: Int { recStore.effectiveTemperature }
  private var snowType: SnowType { recStore.effectiveSnowType }

  private var placedTasks: (placements: [PlacedGanttTask<String, SwixWax>], rowsCount: Int) {
    let ganttTasks: [GanttTask<String, SwixWax>] = selectedWaxes.compactMap { wax in
      guard let r = wax.combinedRange(for: snowType) else { return nil }
      return GanttTask(
        id: wax.id,
        start: Int(Double(r.min)),
        end: Int(Double(r.max)),
        renderItem: wax
      )
    }
    return assignRows(tasks: ganttTasks)
  }

  private var requiredContentHeight: Double {
    let rowCount = max(1, placedTasks.rowsCount)
    return Layout.contentHeight(forRowCount: rowCount)
  }

  var body: some View {
    let tickLineWidth = max(1.0 / Double(displayScale), 1)

    GeometryReader { proxy in
      ZStack(alignment: .top) {
        ScrollView(.horizontal, showsIndicators: false) {
          chartContent(tickLineWidth: tickLineWidth, availableHeight: proxy.size.height)
        }
        .scrollTargetBehavior(
          SnapToClosestDegree(
            snapModulus: Layout.pxPerDegree,
            maxColumnIndex: Layout.degreesCount - 1
          )
        )
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .defaultScrollAnchor(.center)
        .contentMargins(.horizontal, proxy.size.width / 2, for: .scrollContent)
        .sensoryFeedback(.increase, trigger: scrollPosition)
        .onChange(of: temperature, handleTemperatureChange)
        .onChange(of: scrollPosition, handleScrollPositionChange)
        .onAppear(perform: initializeScrollPosition)
        .onDisappear { temperatureDebounceTask?.cancel() }

        TemperatureGauge(temperature: temperature)
          .padding(.top, 10)
      }
    }
    .frame(minHeight: requiredContentHeight)
  }

  // MARK: - Chart Content

  @ViewBuilder
  private func chartContent(tickLineWidth: Double, availableHeight: Double) -> some View {
    let effectiveHeight = max(requiredContentHeight, availableHeight)

    ZStack(alignment: .topLeading) {
      // Invisible degree markers for scroll snapping
      degreeMarkers

      // Wax bars
      barsContent

      // Temperature axis
      XAxisView(
        minTemp: Layout.minTemp,
        maxTemp: Layout.maxTemp,
        pxPerDegree: Layout.pxPerDegree,
        tickXOffset: Layout.tickXOffset,
        tickLineWidth: tickLineWidth,
        axisHeight: Layout.axisHeight,
        centerX: centerX(for: scrollPosition ?? temperature)
      )
      .frame(height: 50)
    }
    .frame(width: Layout.contentWidth, height: effectiveHeight, alignment: .topLeading)
  }

  private var degreeMarkers: some View {
    HStack(spacing: 0) {
      ForEach(Int(Layout.minTemp)...Int(Layout.maxTemp), id: \.self) { degree in
        Color.clear
          .frame(width: Layout.pxPerDegree, height: 1)
          .id(degree)
      }
    }
    .scrollTargetLayout()
  }

  private var barsContent: some View {
    ForEach(placedTasks.placements) { task in
      barView(for: task)
    }
    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: snowType)
    .padding(.top, Layout.barsTopPadding)
  }

  @ViewBuilder
  private func barView(for task: PlacedGanttTask<String, SwixWax>) -> some View {
    let start = clamp(Double(task.start), Layout.minTemp, Layout.maxTemp)
    let end = clamp(Double(task.end), Layout.minTemp, Layout.maxTemp)
    let wax = task.renderItem

    if end > start {
      let xPos = (start - Layout.minTemp) * Layout.pxPerDegree + Layout.tickXOffset
      let width = max(1.0, (end - start) * Layout.pxPerDegree)
      let yPos = Double(task.row) * Layout.rowHeight + Layout.axisHeight

      let baseColor = Color(hex: wax.primaryColor) ?? .blue
      let secondaryColor = wax.secondaryColor.flatMap { Color(hex: $0) }

      GanttBarView(
        wax: wax,
        baseColor: baseColor,
        secondaryColor: secondaryColor,
        barHeight: Layout.barHeight
      )
      .frame(width: width, height: Layout.barHeight)
      .offset(x: xPos, y: yPos)
      .transition(
        .asymmetric(
          insertion: .opacity
            .combined(with: .scale(scale: 0.9, anchor: .leading))
            .combined(with: .offset(x: -20)),
          removal: .opacity
            .combined(with: .scale(scale: 0.9, anchor: .trailing))
        ))
    }
  }

  // MARK: - Helpers

  private func centerX(for temperature: Int) -> Double {
    (Double(clampedTemperature(temperature)) - Layout.minTemp + 0.5) * Layout.pxPerDegree
  }

  private func clampedTemperature(_ t: Int) -> Int {
    Int(clamp(Double(t).rounded(), Layout.minTemp, Layout.maxTemp))
  }

  // MARK: - Scroll Handling

  private func initializeScrollPosition() {
    scrollPosition = clampedTemperature(temperature)
    pendingProgrammaticTarget = nil
    isProgrammaticScroll = false
  }

  private func handleTemperatureChange(_ oldValue: Int, _ newValue: Int) {
    temperatureDebounceTask?.cancel()
    temperatureDebounceTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: Layout.temperatureDebounceNanoseconds)

      let target = clampedTemperature(temperature)
      guard scrollPosition != target || pendingProgrammaticTarget != nil else { return }

      pendingProgrammaticTarget = target
      driveProgrammaticScroll()
    }
  }

  private func handleScrollPositionChange(_ oldValue: Int?, _ newValue: Int?) {
    guard let degree = newValue else { return }
    let clamped = clampedTemperature(degree)

    if isProgrammaticScroll {
      if let pending = pendingProgrammaticTarget, pending == clamped {
        if temperature != clamped { recStore.effectiveTemperature = clamped }
      }
      return
    }

    if clamped != temperature {
      recStore.effectiveTemperature = clamped
    }
  }

  private func driveProgrammaticScroll() {
    guard let target = pendingProgrammaticTarget else { return }

    isProgrammaticScroll = true
    scrollAnimationToken = UUID()
    let token = scrollAnimationToken

    withAnimation(.easeInOut(duration: 0.35)) {
      scrollPosition = target
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
      guard token == scrollAnimationToken else { return }

      if let latest = pendingProgrammaticTarget, latest != scrollPosition {
        driveProgrammaticScroll()
      } else {
        pendingProgrammaticTarget = nil
        isProgrammaticScroll = false
      }
    }
  }
}

// MARK: - Snapping Behavior

struct SnapToClosestDegree: ScrollTargetBehavior {
  let snapModulus: Double
  let maxColumnIndex: Int

  func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
    guard snapModulus > 0 else { return }

    let velocity = context.velocity.dx
    let dampingFactor: Double = 0.03
    let maxExtraColumns: Double = 0.5

    let extraDistance = min(abs(velocity) * dampingFactor, maxExtraColumns * snapModulus)
    let signedExtra = velocity > 0 ? extraDistance : -extraDistance

    let centerX = target.rect.midX + signedExtra

    var columnIndex = Int(((centerX - snapModulus / 2) / snapModulus).rounded())
    columnIndex = max(0, min(columnIndex, maxColumnIndex))

    let snappedCenterX = (Double(columnIndex) + 0.5) * snapModulus
    let dx = snappedCenterX - target.rect.midX

    target.rect = target.rect.offsetBy(dx: dx, dy: 0)
  }
}

// MARK: - Bar View

struct GanttBarView: View {
  let wax: SwixWax
  let baseColor: Color
  let secondaryColor: Color?
  let barHeight: Double

  private var gradientColors: [Color] {
    [baseColor.opacity(0.93), baseColor.opacity(0.72)]
  }

  private var textColor: Color {
    baseColor.isLight ? .black.opacity(0.85) : .white
  }

  var body: some View {
    HStack(spacing: 6) {
      waxIcon
        .frame(width: barHeight * 0.5, height: barHeight * 0.85)

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
        .fill(LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom))
        .overlay {
          Capsule()
            .strokeBorder(baseColor.opacity(0.18), lineWidth: 1)
        }
    }
    .shadow(color: .black.opacity(0.10), radius: 1.5, x: 0, y: 1)
  }

  @ViewBuilder
  private var waxIcon: some View {
    if wax.kind == .klister {
      KlisterCanView(bodyColor: baseColor)
    } else {
      WaxCanGraphic(
        bodyFill: LinearGradient(
          colors: [baseColor, baseColor], startPoint: .top, endPoint: .bottom),
        showBand: secondaryColor != nil,
        bandPrimaryColor: secondaryColor ?? baseColor,
        bandSecondaryColor: secondaryColor
      )
    }
  }
}

// MARK: - Preview

#Preview {
  @Previewable @State var appState = AppState()
  VStack {
    Text("Temperature: \(appState.recommendation.effectiveTemperature)°C")
    Text("Snow Type: \(appState.recommendation.effectiveSnowType.rawValue)")
    Gantt(selectedWaxes: swixWaxes)
      .environment(appState.recommendation)
  }
}
