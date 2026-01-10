//
//  NewGanttDiagram.swift
//  waxappv2
//
//  Created by Herman Henriksen on 02/12/2025.
//

import Foundation
import SwiftUI

struct GanttDiagram: View {
    // Incoming binding from parent
    @Binding var temperature: Int
    var snowType:  SnowType

    @EnvironmentObject private var waxSelectionStore: WaxSelectionStore
    
    // MARK: - Constants
    private let scaleFactor: Int = 50
    private let minValue: Int = -35
    private let maxValue: Int = 35
    private let rowPadding: CGFloat = 0
    private let rowHeight: CGFloat = 40
    
    // Use temperature values directly as scroll IDs for stable, semantic targeting
    private var scrollTargets: [Int] { Array(minValue...maxValue) }
    
    @State private var scrollPosition: Int?
    @State private var isUpdatingFromScroll = false
    @State private var placements: [PlacedGanttTask<String, SwixWax>] = []
    @State private var layoutId = UUID() // Used to trigger transitions
    
    @State private var placementsByRow: [[PlacedGanttTask<String, SwixWax>]] = []
    
    var body: some View {
        HStack {
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack {
                    // Temperature scale track using Int values as scroll IDs
                    LazyHStack(spacing: 0) {
                        ForEach(scrollTargets, id: \.self) { temp in
                            Color.clear
                                .frame(width: CGFloat(scaleFactor))
                                .id(temp)
                        }
                    }
                    .scrollTargetLayout()
                    
                    VStack {
                        GanttContent(
                            placementsByRow: placementsByRow,
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
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .onAppear {
                updateLayout(for: snowType)
                // Initialize scroll position from parent temperature, validating it's in range
                let validTemperature = max(minValue, min(temperature, maxValue))
                scrollPosition = validTemperature
                
                #if DEBUG
                if validTemperature != temperature {
                    print("GanttDiagram: Temperature \(temperature) out of range, clamped to \(validTemperature)")
                }
                print("GanttDiagram: Initial scroll position set to \(validTemperature)")
                #endif
            }
            .onChange(of: scrollPosition) { old, new in
                // Prevent feedback loop: only update temperature if we're not already updating from a temperature change
                guard !isUpdatingFromScroll, let newTemp = new, newTemp != temperature else { return }
                
                isUpdatingFromScroll = true
                defer { isUpdatingFromScroll = false }
                
                #if DEBUG
                print("GanttDiagram: Manual scroll to \(newTemp), updating bound temperature")
                #endif
                
                temperature = newTemp
            }
            .onChange(of: temperature) { oldValue, newValue in
                // Prevent feedback loop: only update scroll position if we're not already updating from scroll
                guard !isUpdatingFromScroll, scrollPosition != newValue else {
                    #if DEBUG
                    if scrollPosition == newValue {
                        print("GanttDiagram: Temperature changed to \(newValue), already at correct position")
                    }
                    #endif
                    return
                }
                
                #if DEBUG
                print("GanttDiagram: Temperature changed from \(oldValue) to \(newValue), scrolling")
                #endif
                
                // Validate the temperature is in range
                guard scrollTargets.contains(newValue) else {
                    #if DEBUG
                    print("GanttDiagram: Warning - temperature \(newValue) out of range [\(minValue), \(maxValue)]")
                    #endif
                    return
                }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollPosition = newValue
                }
            }
            .onChange(of: snowType) { _, newValue in
                updateLayout(for: newValue)
            }
            .onChange(of: waxSelectionStore.selectedWaxIDs) { _, _ in
                updateLayout(for: snowType)
            }
        }
    }
    
    @MainActor
    private func updateLayout(for snowType: SnowType) {
        // Derive layout data. Keep it cheap: group placements once to reduce render cost.
        let waxes = returnWaxesForSnowType(snowType: snowType)
            .filter { waxSelectionStore.isSelected($0) }
            
        let tasks = waxes.map { wax in
            GanttTask(
                id: wax.id,
                start: Int(wax.minValue(for: snowType)),
                end: Int(wax.maxValue(for: snowType)),
                renderItem: wax
            )
        }
        let assigned = assignRows(tasks: tasks, padding: 0)

        var grouped = Array(repeating: [PlacedGanttTask<String, SwixWax>](), count: max(assigned.rowsCount, 0))
        if !grouped.isEmpty {
            for p in assigned.placements {
                if p.row >= 0 && p.row < grouped.count {
                    grouped[p.row].append(p)
                }
            }
        }

        // Keep the animation light; avoid per-item delayed animations.
        withAnimation(.easeInOut(duration: 0.25)) {
            placementsByRow = grouped
            layoutId = UUID()
        }
    }
}

// MARK: - Heavy Content (Equatable to skip body recomputation)
private struct GanttContent: View, Equatable {
    let placementsByRow: [[PlacedGanttTask<String, SwixWax>]]
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
            ForEach(0..<placementsByRow.count, id: \.self) { rowIndex in
                ZStack(alignment: .leading) {
                    let items = placementsByRow[rowIndex]
                    
                    ForEach(items) { item in
                        renderGanttItem(item: item, rowIndex: rowIndex)
                    }
                }
            }
        }
        .allowsHitTesting(false) // Overlay only; scroll interactions belong to the scale
        .animation(.easeInOut(duration: 0.25), value: layoutId)
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
            .transition(.opacity)
    }
}

#Preview {
    @Previewable @State var temperature: Int = 0
    var snowType: SnowType = .fineGrained
    GanttDiagram(temperature: $temperature, snowType: snowType)
        .environmentObject(WaxSelectionStore())
}
