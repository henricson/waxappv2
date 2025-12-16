//
//  NewGanttDiagram.swift
//  waxappv2
//
//  Created by Herman Henriksen on 02/12/2025.
//

import Foundation
import SwiftUI

struct ScrollItem: Identifiable, Hashable {
    var id: UUID
    var value: Int
}

struct GanttDiagram: View {
    // Incoming binding from parent
    @Binding var temperature: Int
    @Binding var snowType: SnowType
    
    // MARK: - Constants
    private let scaleFactor: Int = 50
    private let minValue: Int = -35
    private let maxValue: Int = 35
    private let rowPadding: CGFloat = 0
    private let rowHeight: CGFloat = 40
    
    // Use stable, static IDs so the scroll targets don't churn on re-render
    private static let stableScrollItems: [ScrollItem] = (-35...35).map { value in
        ScrollItem(id: UUID(), value: value)
    }
    private let scrollItems = GanttDiagram.stableScrollItems
    
    // Drive scroll without recomputing the heavy content
    @State private var scrollPosition: ScrollItem?
    
    // Cache heavy layout once; keep identity stable so Equatable subview can skip updates
    struct LayoutCache: Equatable {
        static func == (lhs: GanttDiagram.LayoutCache, rhs: GanttDiagram.LayoutCache) -> Bool {
            return lhs.id == rhs.id
        }
        
        let id = UUID()
        let placements: [PlacedGanttTask<UUID, SwixWax>]
        let rowsCount: Int
    }
    @State private var layout: LayoutCache
    
    // Init to compute layout once
    init(temperature: Binding<Int>, snowType: Binding<SnowType>) {
        self._temperature = temperature
        self._snowType = snowType
        // Precompute layout once in init
        let initialLayout = GanttDiagram.computeLayout(for: snowType.wrappedValue)
        self._layout = State(initialValue: initialLayout)
    }
    
    private static func computeLayout(for type: SnowType) -> LayoutCache {
        let waxes = returnWaxesForSnowType(snowType: type)
        let tasks = waxes.map { wax in
            GanttTask(
                id: UUID(),
                start: Int(wax.minValue(for: type)),
                end: Int(wax.maxValue(for: type)),
                renderItem: wax
            )
        }
        let assigned = assignRows(tasks: tasks, padding: 0)
        return LayoutCache(placements: assigned.placements, rowsCount: assigned.rowsCount)
    }
    
    var body: some View {
        HStack {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    // Temperature scale track with stable IDs
                    LazyHStack(spacing: 0) {
                        ForEach(scrollItems) { item in
                            Color.clear
                                .frame(width: CGFloat(scaleFactor))
                        
                                .id(item)
                        }
                    }
                    .scrollTargetLayout()
                    VStack {
                        
                        GanttContent(
                            layout: layout,
                            minValue: minValue,
                            scaleFactor: scaleFactor,
                            rowHeight: rowHeight
                        )
                        .equatable()
                        
                        XAxisView(minValue: minValue, maxValue: maxValue, scaleFactor: scaleFactor)
                            .frame(height: 50)
                            .padding(.top, 40)
                    }
                }
            }
            .sensoryFeedback(.increase, trigger: scrollPosition)

            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition, anchor: UnitPoint(x: 0.5625, y: 0))
            .onAppear {
                // Initialize scroll position from parent temperature
                if let target = scrollItems.first(where: { $0.value == temperature }) {
                    scrollPosition = target
                }
            }
            .onChange(of: scrollPosition) { old, new in
                // Update parent only when the center target changes
                if let val = new?.value, val != temperature {
                    temperature = val
                }
            }
            .onChange(of: temperature) { _, newValue in
                // When parent pushes a new temperature, update the scroll target
                // This will not re-render the heavy content (isolated in Equatable subview)
                if let target = scrollItems.first(where: { $0.value == newValue }),
                   target != scrollPosition {
                    withAnimation(.easeIn) {
                        scrollPosition = target

                    }
                }
            }
            .onChange(of: snowType) { _, newType in
                layout = GanttDiagram.computeLayout(for: newType)
            }
        }
    }
}

// MARK: - Heavy Content (Equatable to skip body recomputation)
private struct GanttContent: View, Equatable {
    let layout: GanttDiagram.LayoutCache
    let minValue: Int
    let scaleFactor: Int
    let rowHeight: CGFloat
    
    static func == (lhs: GanttContent, rhs: GanttContent) -> Bool {
        // Layout and config are effectively immutable; if equal, skip body updates
        lhs.layout.id == rhs.layout.id &&
        lhs.minValue == rhs.minValue &&
        lhs.scaleFactor == rhs.scaleFactor &&
        lhs.rowHeight == rhs.rowHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<layout.rowsCount, id: \.self) { rowIndex in
                ZStack(alignment: .leading) {
                    let items = layout.placements.filter { $0.row == rowIndex }
                    
                    ForEach(items) { item in
                        renderGanttItem(item: item)
                    }
                }
            }
        }
        .allowsHitTesting(false) // Overlay only; scroll interactions belong to the scale
    }
    
    private func renderGanttItem(item: PlacedGanttTask<UUID, SwixWax>) -> some View {
        let xStart = CGFloat(item.start - minValue) * CGFloat(scaleFactor)
        let width = CGFloat(item.end - item.start) * CGFloat(scaleFactor)
        let wax = item.renderItem
        
        let waxIcon : any View = wax.kind == .hardwax ? WaxCanGraphic(
            bodyFill: AnyShapeStyle(Color(hex: wax.primaryColor) ?? .gray),
            bodyIllumination: LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
            bodySpecular: LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom),
            showBand: true,
            bandPrimaryColor: Color(hex: wax.primaryColor) ?? .white,
            bandSecondaryColor: (wax.secondaryColor.flatMap { Color(hex: $0) }) ?? .blue
        ) : KlisterCanView(bodyColor: (Color(hex: wax.primaryColor) ?? .gray))
        
        return GanttItem(primaryColor: Color(hex: wax.primaryColor) ?? .white, icon: AnyView(waxIcon), title: wax.name)
            .frame(width: width, height: rowHeight)
            .position(x: xStart + width/2, y: rowHeight/2)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var snowType: SnowType = .fineGrained
    @Previewable @State var temperature: Int = 0
    GanttDiagram(temperature: $temperature, snowType: $snowType)
}
