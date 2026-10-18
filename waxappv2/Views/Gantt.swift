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

// MARK: - Layout

private enum GanttLayout {
  static let minTemp: Double = -30
  static let maxTemp: Double = 30
  static let pxPerDegree: Double = 48
  static let axisHeight: Double = 74
  static let rowHeight: Double = 40
  static let barHeight: Double = 32
  static let barsTopPadding: Double = 8
  static let bottomPadding: Double = 12
  /// Clear space between bars sharing a row, in tenths of a degree.
  static let rowGapTenths = 3
  /// The chart never shrinks below this many rows, so a short list doesn't
  /// collapse the page.
  static let minimumRows = 3

  static var degreeRange: ClosedRange<Int> { Int(minTemp)...Int(maxTemp) }
  static var degreesCount: Int { degreeRange.count }
  static var contentWidth: Double { Double(degreesCount) * pxPerDegree }

  /// Centre of a degree's column, in content coordinates.
  static func x(forTemperature t: Double) -> Double {
    (t - minTemp + 0.5) * pxPerDegree
  }

  static func temperature(atX x: Double) -> Double {
    x / pxPerDegree - 0.5 + minTemp
  }

  static func chartHeight(rows: Int) -> Double {
    axisHeight + barsTopPadding + Double(max(rows, minimumRows)) * rowHeight + bottomPadding
  }

  /// Narrowest a bar may be drawn and still show its icon and code.
  static func minimumBarDegrees(forCode code: String) -> Double {
    (50 + 9 * Double(code.count)) / pxPerDegree
  }
}

// MARK: - View

/// The temperature scrubber: every wax in the library as a bar across its
/// range, scrolled under a glass lens that magnifies the temperature it is
/// resting on. Dragging the chart changes the temperature the whole screen
/// recommends for, one detent per degree.
struct Gantt: View {
  @Environment(RecommendationStore.self) private var recStore

  let selectedWaxes: [WaxProduct]

  @State private var position = ScrollPosition(idType: Int.self)
  /// The temperature under the lens, fractional while the chart moves.
  @State private var liveTemperature: Double = 0
  @State private var isUserScrolling = false
  /// Becomes true once the chart has been placed on the current
  /// temperature; until then scroll geometry is layout noise, not input.
  @State private var isReady = false

  private typealias L = GanttLayout

  private var temperature: Int { recStore.effectiveTemperature }
  private var snowType: SnowType { recStore.effectiveSnowType }
  private var liveDegree: Int { Int(liveTemperature.rounded()) }

  // MARK: Rows

  private func placements(for snowType: SnowType) -> (placements: [PlacedGanttTask<String, WaxProduct>], rowsCount: Int) {
    let tasks: [GanttTask<String, WaxProduct>] = selectedWaxes.compactMap { wax in
      guard let range = wax.combinedRange(for: snowType) else { return nil }
      let extent = drawnExtent(for: wax, range: range)
      return GanttTask(
        id: wax.id,
        start: Int((extent.start * 10).rounded()),
        end: Int((extent.end * 10).rounded()),
        renderItem: wax)
    }
    return assignRows(tasks: tasks, padding: L.rowGapTenths)
  }

  /// Height is fixed to the busiest snow type, so switching snow type never
  /// makes the page jump.
  private var stableRowCount: Int {
    SnowType.allCases.map { placements(for: $0).rowsCount }.max() ?? 0
  }

  /// Start and end, in degrees, of the bar as drawn. Ranges too short for
  /// their label grow around their middle, which keeps a single-point wax
  /// centred on its temperature.
  private func drawnExtent(for wax: WaxProduct, range r: TempRangeC) -> (start: Double, end: Double) {
    let start = Double(r.min) - 0.5
    let end = Double(r.max) + 0.5
    let minimum = L.minimumBarDegrees(forCode: wax.code)
    guard end - start < minimum else { return (start, end) }
    let middle = (start + end) / 2
    return (middle - minimum / 2, middle + minimum / 2)
  }

  // MARK: Body

  var body: some View {
    let placed = placements(for: snowType)
    let height = L.chartHeight(rows: stableRowCount)

    GeometryReader { proxy in
      ZStack(alignment: .top) {
        ScrollView(.horizontal) {
          ZStack(alignment: .topLeading) {
            degreeColumns(height: height)
            freezingLine(height: height)
            GanttAxis(liveTemperature: liveTemperature)
              .frame(width: L.contentWidth, height: L.axisHeight)
            bars(placed.placements)
            if placed.placements.isEmpty {
              emptyState(viewportWidth: proxy.size.width)
            }
          }
          .frame(width: L.contentWidth, height: height, alignment: .topLeading)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(SnapToClosestDegree(snapModulus: L.pxPerDegree, maxColumnIndex: L.degreesCount - 1))
        .scrollPosition($position, anchor: .center)
        .contentMargins(.horizontal, max(0, proxy.size.width / 2 - L.pxPerDegree / 2), for: .scrollContent)
        .onScrollGeometryChange(for: Double.self) { geometry in
          L.temperature(atX: geometry.visibleRect.midX)
        } action: { _, new in
          if isReady { liveTemperature = new }
        }
        .onScrollPhaseChange { old, phase in
          isUserScrolling = phase == .interacting || phase == .decelerating
          // Only a drag that has come to rest sets the temperature.
          if phase == .idle, old == .decelerating || old == .interacting { commit(liveDegree) }
        }

        playhead(height: height)
        TemperatureLens(temperature: liveTemperature)
          .padding(.top, 6)
          .allowsHitTesting(false)
      }
    }
    .frame(height: height)
    .task { await placeOnCurrentTemperature() }
    .onChange(of: liveDegree) { _, degree in
      if isUserScrolling { commit(degree) }
    }
    .onChange(of: temperature) { _, newValue in
      guard !isUserScrolling, newValue != liveDegree else { return }
      withAnimation(.smooth(duration: 0.45)) {
        position.scrollTo(id: clamped(newValue), anchor: .center)
      }
    }
    // A detent per degree, a firmer one at freezing, where the wax choice
    // changes most.
    .sensoryFeedback(trigger: liveDegree) { _, degree in
      guard isUserScrolling else { return nil }
      return degree == 0 ? .impact(weight: .medium, intensity: 0.9) : .selection
    }
    .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7), trigger: recStore.topPick?.id) { _, _ in
      isUserScrolling
    }
    .accessibilityElement()
    .accessibilityLabel("Temperature")
    .accessibilityValue(TemperatureDisplay().string(fromCelsius: temperature))
    .accessibilityHint("Swipe up or down to change the temperature")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: recStore.effectiveTemperature = clamped(temperature + 1)
      case .decrement: recStore.effectiveTemperature = clamped(temperature - 1)
      @unknown default: break
      }
    }
  }

  // MARK: Layers

  private func degreeColumns(height: Double) -> some View {
    HStack(spacing: 0) {
      ForEach(L.degreeRange, id: \.self) { degree in
        Color.clear
          .frame(width: L.pxPerDegree, height: height)
          .id(degree)
      }
    }
    .scrollTargetLayout()
  }

  /// A faint dashed line at 0 °C: where grip wax turns to klister.
  private func freezingLine(height: Double) -> some View {
    Path { path in
      let x = L.x(forTemperature: 0)
      path.move(to: CGPoint(x: x, y: L.axisHeight))
      path.addLine(to: CGPoint(x: x, y: height - L.bottomPadding))
    }
    .stroke(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
    .allowsHitTesting(false)
  }

  private func bars(_ placements: [PlacedGanttTask<String, WaxProduct>]) -> some View {
    ForEach(placements) { task in
      let start = Double(task.start) / 10
      let end = Double(task.end) / 10
      let wax = task.renderItem
      let range = wax.combinedRange(for: snowType)

      GanttBarView(
        wax: wax,
        isPinpoint: range.map { $0.min == $0.max } ?? false,
        emphasis: emphasis(for: wax)
      )
      .frame(width: (end - start) * L.pxPerDegree, height: L.barHeight)
      .offset(
        x: (start - L.minTemp) * L.pxPerDegree,
        y: L.axisHeight + L.barsTopPadding + Double(task.row) * L.rowHeight + (L.rowHeight - L.barHeight) / 2)
      .onTapGesture {
        guard let range else { return }
        // Tapping a bar brings its middle under the lens.
        let middle = clamped(Int((Double(range.min + range.max) / 2).rounded()))
        withAnimation(.smooth(duration: 0.45)) {
          position.scrollTo(id: middle, anchor: .center)
        }
        recStore.effectiveTemperature = middle
      }
      .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
    }
    .animation(.smooth(duration: 0.35), value: snowType)
  }

  private func emptyState(viewportWidth: Double) -> some View {
    Text("No wax in your library covers this snow")
      .font(.footnote)
      .foregroundStyle(.secondary)
      .frame(width: viewportWidth * 0.8)
      .position(x: L.x(forTemperature: liveTemperature), y: L.axisHeight + 50)
  }

  private func playhead(height: Double) -> some View {
    LinearGradient(
      colors: [.accentColor.opacity(0.9), .accentColor.opacity(0.08)],
      startPoint: .top, endPoint: .bottom)
      .frame(width: 2, height: height - TemperatureLens.diameter - 6)
      .padding(.top, TemperatureLens.diameter + 6)
      .allowsHitTesting(false)
  }

  // MARK: Helpers

  /// Ties the chart to the hero and "Also works": the pick is outlined, the
  /// other waxes under the lens stay bright, the rest recede.
  private func emphasis(for wax: WaxProduct) -> GanttBarView.Emphasis {
    if wax.id == recStore.topPick?.id { return .topPick }
    return recStore.coversCurrentTemperature(wax) ? .match : .other
  }

  private func clamped(_ t: Int) -> Int {
    min(max(t, Int(L.minTemp)), Int(L.maxTemp))
  }

  private func commit(_ degree: Int) {
    let value = clamped(degree)
    if recStore.effectiveTemperature != value { recStore.effectiveTemperature = value }
  }

  /// Waits one layout pass so the scroll view knows its size, then centres
  /// the current temperature without animation.
  private func placeOnCurrentTemperature() async {
    guard !isReady else { return }
    liveTemperature = Double(temperature)
    await Task.yield()
    position.scrollTo(id: clamped(temperature), anchor: .center)
    try? await Task.sleep(for: .milliseconds(120))
    isReady = true
  }
}

// MARK: - Axis

/// Degree ticks and labels along the top of the chart. Labels fade out as
/// they pass under the lens, which shows them magnified instead.
private struct GanttAxis: View {
  let liveTemperature: Double

  private var display: TemperatureDisplay { TemperatureDisplay() }

  /// Label every degree in Celsius, every other one in Fahrenheit — 1 °C is
  /// 1.8 °F, so labelling them all would collide.
  private var labelStep: Int { display.unit.axisTickStep }

  var body: some View {
    let lensRadiusDegrees = TemperatureLens.diameter / 2 / GanttLayout.pxPerDegree

    ZStack(alignment: .topLeading) {
      ForEach(GanttLayout.degreeRange, id: \.self) { degree in
        let isMajor = degree % labelStep == 0
        let distance = abs(Double(degree) - liveTemperature)
        let underLens = max(0, min(1, (distance - lensRadiusDegrees * 0.55) / (lensRadiusDegrees * 0.5)))

        VStack(spacing: 4) {
          Text(display.degreesOnlyString(fromCelsius: degree))
            .font(.caption2.weight(degree == 0 ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(degree == 0 ? .primary : .secondary)
            .opacity(isMajor ? underLens : 0)
          Capsule()
            .fill(.secondary.opacity(isMajor ? 0.6 : 0.3))
            .frame(width: 1, height: isMajor ? 8 : 5)
        }
        .position(x: GanttLayout.x(forTemperature: Double(degree)), y: TemperatureLens.diameter / 2 + 6)
      }
    }
    .accessibilityHidden(true)
  }
}

// MARK: - Snapping

struct SnapToClosestDegree: ScrollTargetBehavior {
  let snapModulus: Double
  let maxColumnIndex: Int

  func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
    guard snapModulus > 0 else { return }

    // Let a flick carry a little further than where the finger left off.
    let velocity = context.velocity.dx
    let extra = min(abs(velocity) * 0.03, 0.5 * snapModulus) * (velocity > 0 ? 1 : -1)

    let centerX = target.rect.midX + extra
    var column = Int(((centerX - snapModulus / 2) / snapModulus).rounded())
    column = max(0, min(column, maxColumnIndex))

    let snapped = (Double(column) + 0.5) * snapModulus
    target.rect = target.rect.offsetBy(dx: snapped - target.rect.midX, dy: 0)
  }
}

// MARK: - Bar

struct GanttBarView: View {
  let wax: WaxProduct
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

  private var fill: Color { Color(hex: wax.backgroundColor) ?? .blue }
  private var textColor: Color { fill.isLight ? .black.opacity(0.85) : .white }

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
        .frame(width: 14, height: 22)

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
    .padding(.horizontal, 10)
    .frame(maxHeight: .infinity)
    .background {
      Capsule()
        .fill(LinearGradient(colors: [fill.opacity(0.96), fill.opacity(0.78)], startPoint: .top, endPoint: .bottom))
        .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.75))
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
    .contentShape(.capsule)
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(wax.code), \(wax.name), \(wax.brand.displayName)")
  }
}

// MARK: - Preview

#Preview {
  @Previewable @State var appState = AppState()
  Gantt(selectedWaxes: WaxCatalog.all.filter { $0.domain == .grip })
    .environment(appState.recommendation)
}
