import SwiftUI
import StoreKit
import Observation

struct PaywallView: View {
    @Environment(StoreManager.self) private var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss

    private let imageMaxSize: CGFloat = 420

    private var priceLine: String? {
        guard let product = storeManager.primaryProduct else { return nil }
        if let period = storeManager.subscriptionPeriodText(for: product) {
            return "\(product.displayPrice)/\(period)"
        }
        return product.displayPrice
    }

    private var primaryButtonTitle: String {
        if storeManager.isEligibleForIntroOffer {
            return "Start 14-day free trial"
        }
        return "Subscribe"
    }

    var body: some View {
        NavigationStack {
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
                        Text("GetGrip Premium")
                            .font(.largeTitle)
                            .bold()
                            .multilineTextAlignment(.center)

                        Group {
                            if !storeManager.hasAccess {
                                if storeManager.isEligibleForIntroOffer {
                                    Text("Start your 14-day free trial to unlock full access. Cancel anytime before the trial ends.")
                                } else {
                                    Text("Subscribe to unlock full access. Cancel anytime.")
                                }
                            } else {
                                Text("Your subscription is active. Enjoy unlimited access across all devices.")
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
                        if let error = storeManager.productsError {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(.orange)
                                
                                Text("Unable to Load Products")
                                    .font(.headline)

                                Text(error)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("Try Again") {
                                    Task {
                                        await storeManager.retryFetchProducts()
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding()
                        } else if let product = storeManager.primaryProduct {
                            Button {
                                Task {
                                    await storeManager.purchase(product)
                                }
                            } label: {
                                HStack {
                                    if storeManager.isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        Text("Processing...")
                                    } else {
                                        Text(primaryButtonTitle)
                                        Spacer()
                                        Text(priceLine ?? product.displayPrice)
                                    }
                                }
                                .bold()
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(storeManager.isPurchasing)
                            .opacity(storeManager.isPurchasing ? 0.6 : 1.0)
                            
                            if let purchaseError = storeManager.purchaseError {
                                Text(purchaseError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            ProgressView("Loading products...")
                        }

                        Button("Restore Subscription") {
                            Task {
                                await storeManager.restorePurchases()
                            }
                        }
                        .font(.footnote)

                        Text("By continuing, you verify that you are at least 14 years old and agree to our Terms of Service and Privacy Policy.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 24)
            }
            .padding(.top, 20)
            .padding(.horizontal)
#if os(iOS)

            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                // Close button - only show if the user already has access
                if storeManager.hasAccess {
#if os(iOS)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
#else
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }
#endif
                }
            }
            .interactiveDismissDisabled(!storeManager.hasAccess)
            .onChange(of: storeManager.hasAccess) { _, newValue in
                if newValue {
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    PaywallView()
        .environment(StoreManager())
}