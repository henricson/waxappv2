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

    /// Resolved trial start date (after CloudKit sync). Used to drive UI.
    @Published private(set) var cachedTrialStartDate: Date?

    private let productIds = ["com.waxappv2.lifetime"] // Replace with your actual Product ID

    private let trialStartDateKey = "trialStartDate" // legacy UserDefaults key
    private let trialStartDateKeychainKey = "trialStartDateISO8601"
    private let iso8601 = ISO8601DateFormatter()

    private let trialStore = CloudKitTrialStore()

    private var updateListenerTask: Task<Void, Error>? = nil

    var trialStartDate: Date {
        // Prefer CloudKit-synced date once available.
        if let cachedTrialStartDate {
            return cachedTrialStartDate
        }

        // Immediate local fallback.
        if let s = try? KeychainService.getString(forKey: trialStartDateKeychainKey),
           let d = iso8601.date(from: s) {
            return d
        }

        // First run before CloudKit has resolved.
        let now = Date()
        try? KeychainService.setString(iso8601.string(from: now), forKey: trialStartDateKeychainKey)
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
        // Migrate legacy UserDefaults -> Keychain so existing users keep their original start date.
        if let legacy = UserDefaults.standard.object(forKey: trialStartDateKey) as? Date {
            try? KeychainService.setString(iso8601.string(from: legacy), forKey: trialStartDateKeychainKey)
            UserDefaults.standard.removeObject(forKey: trialStartDateKey)
        }

        // Ensure local fallback exists immediately.
        _ = trialStartDate

        // Resolve and enforce earliest date across devices via CloudKit.
        Task { [weak self] in
            guard let self else { return }

            let localDate: Date? = {
                if let s = try? KeychainService.getString(forKey: self.trialStartDateKeychainKey),
                   let d = self.iso8601.date(from: s) {
                    return d
                }
                return nil
            }()

            // Candidate date to enforce (prefer existing local, otherwise now).
            let candidate = localDate ?? Date()

            do {
                // Store earliest date in CloudKit and get effective date back.
                let effective = try await self.trialStore.upsertEarliestTrialStartDate(candidate)

                // Cache + persist to Keychain.
                self.cachedTrialStartDate = effective
                try? KeychainService.setString(self.iso8601.string(from: effective), forKey: self.trialStartDateKeychainKey)

                // Ensure UI recomputes trialStatus.
                self.objectWillChange.send()
            } catch {
                // CloudKit not available (no iCloud login, network, entitlements). Stick to local fallback.
                self.cachedTrialStartDate = localDate
            }
        }

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
