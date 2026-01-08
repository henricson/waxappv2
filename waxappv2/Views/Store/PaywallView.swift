import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss

    private let imageMaxSize: CGFloat = 420

    var body: some View {
        VStack(spacing: 0) {
            // Top hero image (same style/size as onboarding)
            Image("post-introduction-background")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: imageMaxSize, maxHeight: imageMaxSize)
                .accessibilityHidden(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom text + buttons
            VStack(spacing: 16) {
                VStack(spacing: 10) {
                    Text("Unlock GetGrip")
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)

                    Group {
                        if storeManager.trialStatus == .expired {
                            Text("Your 14-day free trial has ended. Purchase the full version to continue.")
                        } else {
                            Text("Support the development and unlock all features.")
                        }
                    }
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                VStack(spacing: 16) {
                    if let product = storeManager.products.first {
                        Button {
                            Task {
                                try? await storeManager.purchase(product)
                            }
                        } label: {
                            HStack {
                                Text("Purchase")
                                Spacer()
                                Text(product.displayPrice)
                            }
                            .bold()
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    } else {
                        ProgressView("Loading products...")
                    }

                    Button("Restore Purchases") {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    }
                    .font(.footnote)

                    Text("By continuing, you verify that you are at least 14 years old and agree to our Terms of Service and Privacy Policy.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .padding(.top, 20)
        .padding(.horizontal)
        .onChange(of: storeManager.isPurchased) { purchased in
            if purchased {
                dismiss()
            }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
}
