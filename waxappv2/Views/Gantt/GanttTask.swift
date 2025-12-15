//
//  GanttTask.swift
//  waxappv2
//
//  Created by Herman Henriksen on 03/12/2025.
//
import Foundation

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

// Internal heap slot
private struct RowSlot {
    var nextFree: Int
    let rowIndex: Int
}

// MARK: - Row Assignment Algorithm

func assignRows<ID: Hashable, T>(
    tasks: [GanttTask<ID, T>],
    padding: Int = 0
) -> (placements: [PlacedGanttTask<ID, T>], rowsCount: Int) {
    #if DEBUG
    for t in tasks {
        precondition(t.start <= t.end, "Task \(t.id) har start > end")
    }
    #endif

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
