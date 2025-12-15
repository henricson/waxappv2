import SwiftUI

struct RecommendedWaxesGridView: View {
    let waxes: [SwixWax]

    // Adaptive columns to fit nicely on iPhone and iPad
    private let columns = [
        GridItem(.adaptive(minimum: 140), spacing: 16, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(waxes) { wax in
                RecommendedWaxCanView(wax: wax)
            }
        }
    }
}
