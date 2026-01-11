import SwiftUI

struct ScrollItem: Identifiable, Hashable {
    let id = UUID()
    let number: Int
}

struct ScrollTest: View {
    let pillSize = CGSize(width: 110, height: 80)

    
    let items = (0..<100).map { ScrollItem(number: $0) }

    var body: some View {
        GeometryReader { proxy in
            
            ZStack {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 40) {
                        ForEach(items) { item in
                            Rectangle()
                                .frame(width: pillSize.width, height: 100)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, (proxy.size.width - pillSize.width) / 2)
                .scrollTargetBehavior(.viewAligned)
                .defaultScrollAnchor(.center)
                
                Rectangle()
                    .frame(width: 1)
            }
        }
    }
}

#Preview {
    ScrollTest()
}
