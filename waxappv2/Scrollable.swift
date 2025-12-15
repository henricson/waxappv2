import SwiftUI


struct Scrollable: View {
    // Create items once on init; this ensures stable identity across renders
    private let items: [Int] = Array(-25..<25)

    // Bind the scroll position to the item's ID
    @State private var selectedID: Int?

    // Keep margins stable across layout passes
    @State private var contentPadding: CGFloat = 0

    private let itemSize: CGFloat = 50
    private let itemSpacing: CGFloat = 12

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(items, id: \.self) { item in
                            RoundedRectangle(cornerRadius: 25)
                                .aspectRatio(16.0/9.0, contentMode: .fit)

                                .overlay(
                                    Text(String(item))
                                        .foregroundStyle(.black)
                                )
                                .containerRelativeFrame(
                                                            .horizontal,
                                                            count: 3,
                                                            span: 1,
                                                            spacing: 10
                                                            )
                                .id(item) // stable target IDs

                             
                        }
                    }
                    .scrollTargetLayout()

                }
                // Margin applied to scroll content, computed once on size changes
                // Single anchoring strategy: snap to center
                .scrollTargetBehavior(.viewAligned)
                // Explicit anchor for both user and programmatic scrolling
                .scrollPosition(id: $selectedID, anchor: .center)
                // Compute margins when size changes; avoids mid-pass adjustments
                .onAppear {
                    print(geometry.size.width)
                    self.selectedID = 4
                }
            }
            .frame(height: 100)

            // Example programmatic controls
            HStack {
                Button("Center 0") {
                    withAnimation(.snappy) { selectedID = 0 }
                }
                Button("Center 10") {
                    withAnimation(.snappy) { selectedID = 10 }
                }
                Button("Center -10") {
                    withAnimation(.snappy) { selectedID = -10 }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    Scrollable()
}
