//
//  XAxisView.swift
//  waxappv2
//
//  Created by Herman Henriksen on 13/01/2026.
//

import SwiftUI

struct XAxisView : View {
    var minTemp: Double
    var maxTemp: Double
    var pxPerDegree: Double
    var tickXOffset: Double
    var tickLineWidth : Double
    var axisHeight : Double
    var centerX: CGFloat
    
    var body : some View {
        GeometryReader { geometry in
            ForEach(Int(minTemp)...Int(maxTemp), id: \.self) { degree in
                let x = (Double(degree) - minTemp) * pxPerDegree + tickXOffset
                VStack(spacing: 2) {
                    Text("\(degree)°")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(.secondary.opacity(0.6))
                        .frame(width: tickLineWidth, height: 8)
                }
                .position(x: x, y: geometry.size.height - 15)
            }
        }
    }
}

#Preview {
    ScrollView(.horizontal) {
        XAxisView(
            minTemp: -30, maxTemp: 30, pxPerDegree: 50, tickXOffset: 50, tickLineWidth: 1, axisHeight: 10, centerX: 3050 / 2
        )
        .background(.blue)
        .frame(width: 3050, height: 50)
    }
}
