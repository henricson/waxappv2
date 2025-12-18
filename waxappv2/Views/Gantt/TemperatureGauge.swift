import SwiftUI

struct TemperatureGauge: View {
    var temperature : Int

    var body: some View {
            Rectangle()
                .foregroundStyle(.red)
                .frame(width: 5) // fixed height so it won’t stretch
                .clipShape(RoundedRectangle(cornerRadius: 6))

            
            .background(.red)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        
        .shadow(radius: 4)
        // No maxHeight: .infinity here, so it hugs content
    }
}

#Preview {
    TemperatureGauge(temperature: -5)
}
