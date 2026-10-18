//
//  GanttTask.swift
//  waxappv2
//
//  Created by Herman Henriksen on 03/12/2025.
//
import Foundation
import SwiftUI

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
  /// Clear space between bars sharing a row, in tenths of a degree.
  static let rowGapTenths = 3

  /// Narrowest a bar may be drawn and still show its icon and code.
  static func minimumBarDegrees(forCode code: String) -> Double {
    let points = 46 + 9 * Double(code.count)
    return points / pxPerDegree
  }

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

  let selectedWaxes: [WaxProduct]

  @State private var scrollPosition: Int?
  @State private var isProgrammaticScroll = false
  @State private var pendingProgrammaticTarget: Int?
  @State private var scrollAnimationToken = UUID()
  @State private var temperatureDebounceTask: Task<Void, Never>?

  private typealias Layout = GanttLayoutConstants

  private var temperature: Int { recStore.effectiveTemperature }
  private var snowType: SnowType { recStore.effectiveSnowType }

  /// Bars are placed in tenths of a degree using the extent they are drawn
  /// at, not just the published range. Single-point and one-degree waxes
  /// are widened to fit their label, and rows are packed with a small gap,
  /// so a cluster of 0 °C waxes no longer stacks bars on top of each other.
  private var placedTasks: (placements: [PlacedGanttTask<String, WaxProduct>], rowsCount: Int) {
    let ganttTasks: [GanttTask<String, WaxProduct>] = selectedWaxes.compactMap { wax in
      guard let r = wax.combinedRange(for: snowType) else { return nil }
      let extent = drawnExtent(for: wax, range: r)
      return GanttTask(
        id: wax.id,
        start: Int((extent.start * 10).rounded()),
        end: Int((extent.end * 10).rounded()),
        renderItem: wax
      )
    }
    return assignRows(tasks: ganttTasks, padding: Layout.rowGapTenths)
  }

  /// Start and end in degrees of the bar as drawn.
  private func drawnExtent(for wax: WaxProduct, range r: TempRangeC) -> (start: Double, end: Double) {
    let start = Double(r.min)
    let span = Double(r.max - r.min)
    let minimum = Layout.minimumBarDegrees(forCode: wax.code)

    if span >= minimum { return (start, start + span) }
    // Too short for its label: grow around the middle of the range, which
    // keeps a single-point wax centred on its temperature.
    let middle = start + span / 2
    return (middle - minimum / 2, middle + minimum / 2)
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
  private func barView(for task: PlacedGanttTask<String, WaxProduct>) -> some View {
    let start = clamp(Double(task.start) / 10, Layout.minTemp, Layout.maxTemp)
    let end = clamp(Double(task.end) / 10, Layout.minTemp, Layout.maxTemp)
    let wax = task.renderItem
    let range = wax.combinedRange(for: snowType)

    let xPos = (start - Layout.minTemp) * Layout.pxPerDegree + Layout.tickXOffset
    let width = max(Layout.pxPerDegree, (end - start) * Layout.pxPerDegree)
    let yPos = Double(task.row) * Layout.rowHeight + Layout.axisHeight

    let baseColor = Color(hex: wax.primaryColor) ?? .blue
    let secondaryColor = wax.secondaryColor.flatMap { Color(hex: $0) }

    GanttBarView(
      wax: wax,
      baseColor: baseColor,
      secondaryColor: secondaryColor,
      barHeight: Layout.barHeight,
      // A manufacturer may publish a single-point range (Swix V50 is
      // "0 °C" exactly); its bar is widened to fit, and marked as a point.
      isPinpoint: range.map { $0.min == $0.max } ?? false,
      emphasis: emphasis(for: wax)
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

  // MARK: - Helpers

  /// Ties the chart to the hero and "Also works": the pick is outlined, the
  /// other waxes under the temperature line stay bright, the rest recede.
  private func emphasis(for wax: WaxProduct) -> GanttBarView.Emphasis {
    if wax.id == recStore.topPick?.id { return .topPick }
    return recStore.coversCurrentTemperature(wax) ? .match : .other
  }

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
  let wax: WaxProduct
  let baseColor: Color
  let secondaryColor: Color?
  let barHeight: Double
  /// True when the manufacturer publishes a single temperature, not a range.
  var isPinpoint: Bool = false
  var emphasis: Emphasis = .match

  enum Emphasis {
    /// The wax shown in the hero.
    case topPick
    /// Covers the current temperature, as listed under "Also works".
    case match
    /// Out of range here; shown for context only.
    case other
  }

  private var fillColor: Color {
    Color(hex: wax.backgroundColor) ?? baseColor
  }

  private var gradientColors: [Color] {
    [fillColor.opacity(0.95), fillColor.opacity(0.74)]
  }

  private var textColor: Color {
    fillColor.isLight ? .black.opacity(0.85) : .white
  }

  private var code: some View {
    Text(isPinpoint ? "\(wax.code) ·" : wax.code)
      .font(.caption.weight(.semibold))
      .foregroundStyle(textColor)
      .lineLimit(1)
      .fixedSize()
  }

  var body: some View {
    HStack(spacing: 6) {
      WaxIcon(product: wax)
        .frame(width: barHeight * 0.5, height: barHeight * 0.85)

      // The name only appears when the bar has room for all of it; a
      // truncated "Ro…" reads as clutter.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 6) {
          code
          Text(wax.name)
            .font(.caption2)
            .foregroundStyle(textColor.opacity(0.75))
            .lineLimit(1)
            .fixedSize()
        }
        code
      }

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background {
      Capsule()
        .fill(LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom))
        .overlay {
          Capsule()
            .strokeBorder(.white.opacity(0.22), lineWidth: 0.75)
        }
    }
    .overlay {
      if emphasis == .topPick {
        Capsule()
          .strokeBorder(Color.primary.opacity(0.85), lineWidth: 2)
          .padding(-3)
      }
    }
    .saturation(emphasis == .other ? 0.35 : 1)
    .opacity(emphasis == .other ? 0.45 : 1)
    .shadow(color: .black.opacity(emphasis == .other ? 0 : 0.12), radius: 2, y: 1)
    .animation(.smooth(duration: 0.25), value: emphasis)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(wax.code), \(wax.name), \(wax.brand.displayName)")
  }
}

// MARK: - Preview

#Preview {
  @Previewable @State var appState = AppState()
  VStack {
    Text("Temperature: \(appState.recommendation.effectiveTemperature)°C")
    Text("Snow Type: \(appState.recommendation.effectiveSnowType.rawValue)")
    Gantt(selectedWaxes: WaxCatalog.all)
      .environment(appState.recommendation)
  }
}
