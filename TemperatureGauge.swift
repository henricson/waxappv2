//
//  TemperatureGauge.swift
//  waxappv2
//
//  Created by Herman Henriksen on 13/01/2026.
//

import SwiftUI

struct TemperatureGauge : View {
    var temperature: Int
    
    var body : some View {
        VStack(spacing: 0) {
            // Rounded badge with temperature
            ZStack {
                RoundedRectangle(cornerRadius: 40)
                    .fill(.red)
                    .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                    .frame(width: 60, height: 40)
                
                Text("\(temperature)°")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            
            // Vertical line extending to bottom
            Rectangle()
                .fill(.red.gradient)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
    }
}

#Preview {
    TemperatureGauge(temperature: -5)
        .frame(height: 300)
}
