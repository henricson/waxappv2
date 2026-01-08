import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "crown.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.yellow)
            
            Text("Unlock WaxApp")
                .font(.largeTitle)
                .bold()
            
            if storeManager.trialStatus == .expired {
                Text("Your 14-day free trial has ended. Purchase the full version to continue.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                 Text("Support the development and unlock all features forever.")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                if let product = storeManager.products.first {
                    Button(action: {
                        Task {
                            try? await storeManager.purchase(product)
                        }
                    }) {
                        HStack {
                            Text("Buy Lifetime Access")
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
            }
            .padding(.horizontal)
            
            Spacer()
            
            Text("By continuing, you verify that you are at least 14 years old and agree to our Terms of Service and Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .padding()
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
