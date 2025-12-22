//
//  NewGanttDiagram.swift
//  waxappv2
//
//  Created by Herman Henriksen on 02/12/2025.
//

import Foundation
import SwiftUI

struct ScrollItem:  Identifiable, Hashable {
    var id: UUID
    var value: Int
}

struct GanttDiagram: View {
    // Incoming binding from parent
    @Binding var temperature: Int
    var snowType:  SnowType
    
    // MARK: - Constants
    private let scaleFactor: Int = 50
    private let minValue: Int = -35
    private let maxValue: Int = 35
    private let rowPadding: CGFloat = 0
    private let rowHeight: CGFloat = 40
    
    // Use stable, static IDs so the scroll targets don't churn on re-render
    private static let stableScrollItems: [ScrollItem] = (-35...35).map { value in
        ScrollItem(id:  UUID(), value: value)
    }
    private let scrollItems = GanttDiagram.stableScrollItems
    
    @State private var scrollPosition: ScrollItem?
    @State private var placements: [PlacedGanttTask<String, SwixWax>] = []
    @State private var rowsCount: Int = 0
    @State private var layoutId = UUID() // Used to trigger transitions
    
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
                            placements: placements,
                            rowsCount: rowsCount,
                            minValue: minValue,
                            scaleFactor: scaleFactor,
                            rowHeight: rowHeight,
                            layoutId: layoutId
                        )
                        .equatable()
                        
                        XAxisView(minValue: minValue, maxValue: maxValue, scaleFactor: scaleFactor)
                            .frame(height: 50)
                            .padding(.top, 40)
                    }
                }
            }
            .coordinateSpace(name: "ganttScroll")
            .sensoryFeedback(.increase, trigger: scrollPosition)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition, anchor:  UnitPoint(x: 0.5625, y: 0))
            .onAppear {
                updateLayout()
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
                if let target = scrollItems.first(where: { $0.value == newValue }),
                   target != scrollPosition {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        scrollPosition = target
                    }
                }
            }
            .onChange(of: snowType) { _, _ in
                updateLayout()
            }
        }
    }
    
    private func updateLayout() {
        let waxes = returnWaxesForSnowType(snowType: snowType)
        let tasks = waxes.map { wax in
            GanttTask(
                id: wax.id,
                start: Int(wax.minValue(for: snowType)),
                end: Int(wax.maxValue(for: snowType)),
                renderItem: wax
            )
        }
        let assigned = assignRows(tasks: tasks, padding: 0)
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0)) {
            placements = assigned.placements
            rowsCount = assigned.rowsCount
            layoutId = UUID() // Trigger transition
        }
    }
}

// MARK: - Heavy Content (Equatable to skip body recomputation)
private struct GanttContent: View, Equatable {
    let placements: [PlacedGanttTask<String, SwixWax>]
    let rowsCount: Int
    let minValue: Int
    let scaleFactor: Int
    let rowHeight: CGFloat
    let layoutId: UUID
    
    static func == (lhs: GanttContent, rhs: GanttContent) -> Bool {
        lhs.layoutId == rhs.layoutId &&
        lhs.minValue == rhs.minValue &&
        lhs.scaleFactor == rhs.scaleFactor &&
        lhs.rowHeight == rhs.rowHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<rowsCount, id: \.self) { rowIndex in
                ZStack(alignment: .leading) {
                    let items = placements.filter { $0.row == rowIndex }
                    
                    ForEach(items) { item in
                        renderGanttItem(item: item, rowIndex: rowIndex)
                    }
                }
            }
        }
        .allowsHitTesting(false) // Overlay only; scroll interactions belong to the scale
    }
    
    private func renderGanttItem(item: PlacedGanttTask<String, SwixWax>, rowIndex: Int) -> some View {
        let xStart = CGFloat(item.start - minValue) * CGFloat(scaleFactor)
        let width = CGFloat(item.end - item.start) * CGFloat(scaleFactor)
        let wax = item.renderItem
        
        let waxIcon : any View = wax.kind == .hardwax ? WaxCanGraphic(
            bodyFill: AnyShapeStyle(Color(hex: wax.primaryColor) ?? .gray),
            bodyIllumination: LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
            bodySpecular: LinearGradient(colors: [.white.opacity(0.25), .clear], startPoint: .top, endPoint: .bottom),
            showBand: true,
            bandPrimaryColor: Color(hex:  wax.primaryColor) ?? .white,
            bandSecondaryColor: (wax.secondaryColor.flatMap { Color(hex: $0) }) ?? .blue
        ) : KlisterCanView(bodyColor: (Color(hex: wax.primaryColor) ?? .gray))
        
        return GanttItem(primaryColor: Color(hex: wax.primaryColor) ?? .white, icon: AnyView(waxIcon), title: wax.name)
            .frame(width: width, height: rowHeight)
            .position(x: xStart + width/2, y: rowHeight/2)
            .transition(. asymmetric(
                insertion:  .scale(scale: 0.92).combined(with: .opacity),
                removal: .scale(scale: 0.96).combined(with: .opacity)
            ))
            .animation(
                .spring(response: 0.5, dampingFraction: 0.75)
                    . delay(Double(rowIndex) * 0.05),
                value: layoutId
            )
    }
}

// MARK:  - Preview

#Preview {
    @Previewable @State var temperature: Int = 0
    var snowType: SnowType = .fineGrained
    GanttDiagram(temperature: $temperature, snowType: snowType)
}
