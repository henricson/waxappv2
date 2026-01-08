import Foundation
import StoreKit
import SwiftUI
import Combine

enum TrialStatus: Equatable {
    case active
    case warning(daysLeft: Int)
    case expired
}

@MainActor
class StoreManager: ObservableObject {
    @Published var isPurchased: Bool = false
    @Published var products: [Product] = []
    
    private let productIds = ["com.waxappv2.lifetime"] // Replace with your actual Product ID
    private let trialStartDateKey = "trialStartDate"
    private var updateListenerTask: Task<Void, Error>? = nil
    
    var trialStartDate: Date {
        if let date = UserDefaults.standard.object(forKey: trialStartDateKey) as? Date {
            return date
        }
        let now = Date()
        UserDefaults.standard.set(now, forKey: trialStartDateKey)
        return now
    }
    
    var daysSinceStart: Int {
        let calendar = Calendar.current
        let start = trialStartDate
        let now = Date()
        let components = calendar.dateComponents([.day], from: start, to: now)
        return components.day ?? 0
    }
    
    var trialStatus: TrialStatus {
        let days = daysSinceStart
        if days >= 14 {
            return .expired
        } else if days >= 10 {
            return .warning(daysLeft: 14 - days)
        } else {
            return .active
        }
    }
    
    init() {
        // Ensure trial start date is set
        _ = trialStartDate
        
        updateListenerTask = listenForTransactions()
        
        Task {
            await updatePurchasedStatus()
            await fetchProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                switch result {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.updatePurchasedStatus()
                case .unverified:
                    print("Transaction unverified")
                }
            }
        }
    }
    
    func fetchProducts() async {
        do {
            let products = try await Product.products(for: productIds)
            self.products = products
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await updatePurchasedStatus()
            case .unverified:
                break
            }
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }
    
    func updatePurchasedStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIds.contains(transaction.productID) {
                    isPurchased = true
                    return
                }
            }
        }
        isPurchased = false
    }
    
    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedStatus()
    }
}
