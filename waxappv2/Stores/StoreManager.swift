//
//  StoreManager.swift
//  waxappv2
//
//  Created by Herman Henriksen on 10/01/2026.
//

import Foundation
import StoreKit
import SwiftUI

enum AccessState: Equatable {
    case loading
    case notSubscribed
    case trialActive(daysLeft: Int)
    case subscribed
    case gracePeriod
    case billingRetry
    case expired
    case revoked

    var hasAccess: Bool {
        switch self {
        case .trialActive, .subscribed, .gracePeriod, .billingRetry:
            return true
        case .loading, .notSubscribed, .expired, .revoked:
            return false
        }
    }
}

@MainActor
@Observable final class StoreManager {
    var products: [Product] = []
    var productsError: String?
    var isPurchasing: Bool = false
    var purchaseError: String?
    var accessState: AccessState = .loading
    var isInitialized: Bool = false
    var isEligibleForIntroOffer: Bool = false

    private let productIds = ["no.squarewave.getgrip.annual_subscription"]

    /// Must be optional because it’s created after init begins, and it’s cancelled in deinit.
    private var updateListenerTask: Task<Void, Never>?
    
    /// Flag to track if a refresh is currently in progress (replaces task-based coalescing)
    private var isRefreshing: Bool = false

    var primaryProduct: Product? {
        products.first
    }

    var hasAccess: Bool {
        accessState.hasAccess
    }

    var trialDaysRemaining: Int? {
        if case .trialActive(let daysLeft) = accessState {
            return daysLeft
        }
        return nil
    }

    init() {
        #if DEBUG
        print("\n🚀 StoreManager initializing...")
        #endif

        // This is @MainActor init, so storing the task is safe.
        updateListenerTask = listenForTransactions()

        Task { [weak self] in
            guard let self else { return }
            await self.refreshAll()
            #if DEBUG
            print("✅ StoreManager fully initialized")
            #endif
        }

        #if DEBUG
        print("✅ StoreManager initialized\n")
        #endif
    }

    deinit {
        // `deinit` is nonisolated. Don't read main-actor isolated properties here.
        // Instead, cancel via a helper that hops to the main actor.
        cancelUpdateListenerTaskOnMainActor()
    }

    nonisolated private func cancelUpdateListenerTaskOnMainActor() {
        Task { @MainActor [weak self] in
            self?.updateListenerTask?.cancel()
        }
    }

    // MARK: - Public API

    func refreshAll(force: Bool = false) async {
        // Coalesce refresh calls using a simple flag
        // Since we're on MainActor, this is thread-safe
        guard !isRefreshing || force else {
            return
        }

        if isInitialized && !force {
            await updateAccessState()
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }
        
        await fetchProducts()
        await updateAccessState()
        isInitialized = true
    }

    func fetchProducts() async {
        do {
            #if DEBUG
            print("🛒 Fetching products for IDs: \(productIds)")
            #endif
            let products = try await Product.products(for: productIds)
            let sorted = products.sorted { $0.price < $1.price }

            self.products = sorted
            self.productsError = nil

            if let first = sorted.first {
                // StoreKit eligibility can be async.
                self.isEligibleForIntroOffer = await (first.subscription?.isEligibleForIntroOffer ?? false)
            } else {
                self.isEligibleForIntroOffer = false
            }

            if sorted.isEmpty {
                let errorMsg = "No products found. Check: 1) Product ID matches App Store Connect 2) Paid Apps Agreement signed 3) Product is 'Ready to Submit'"
                #if DEBUG
                print("⚠️ \(errorMsg)")
                #endif
                self.productsError = errorMsg
            } else {
                #if DEBUG
                print("✅ Loaded \(sorted.count) product(s)")
                for product in sorted {
                    print("   - \(product.id): \(product.displayName) (\(product.displayPrice))")
                }
                #endif
            }
        } catch {
            let errorMsg = "Failed to load products: \(error.localizedDescription)"
            #if DEBUG
            print("❌ \(errorMsg)")
            #endif
            self.productsError = errorMsg
        }
    }

    /// Retry fetching products with exponential backoff
    func retryFetchProducts(maxAttempts: Int = 3) async {
        for attempt in 1...maxAttempts {
            await fetchProducts()

            if !products.isEmpty {
                return
            }

            if attempt < maxAttempts {
                let delay = Double(attempt * attempt)
                #if DEBUG
                print("⏳ Retrying in \(delay) seconds... (attempt \(attempt)/\(maxAttempts))")
                #endif
                try? await Task.sleep(for: .seconds(delay))
            }
        }

        #if DEBUG
        print("❌ Failed to load products after \(maxAttempts) attempts")
        #endif
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else {
            #if DEBUG
            print("⚠️ Purchase already in progress")
            #endif
            return
        }

        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    // Update state first, then finish. Finishing early can sometimes remove
                    // the transaction from streams before we read it (flicker / notSubscribed).
                    await updateAccessState()
                    await transaction.finish()
                    #if DEBUG
                    print("✅ Purchase successful")
                    #endif
                case .unverified:
                    purchaseError = "Purchase verification failed."
                    #if DEBUG
                    print("❌ Purchase verification failed")
                    #endif
                }
            case .userCancelled:
                #if DEBUG
                print("ℹ️ User cancelled purchase")
                #endif
            case .pending:
                #if DEBUG
                print("⏳ Purchase pending")
                #endif
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
            #if DEBUG
            print("❌ Purchase failed: \(error.localizedDescription)")
            #endif
        }
    }

    func restorePurchases() async {
        purchaseError = nil
        do {
            try await AppStore.sync()
        } catch {
            purchaseError = error.localizedDescription
            #if DEBUG
            print("⚠️ Restore failed: \(error.localizedDescription)")
            #endif
        }
        await updateAccessState()
        #if DEBUG
        print("🔄 Restore purchases completed")
        #endif
    }

    // MARK: - Subscription State

    func updateAccessState() async {
        // Ensure we have products before checking subscription status; otherwise we fall back
        // to entitlement scan only (which can be slower / less descriptive).
        if products.isEmpty {
            await fetchProducts()
        }

        guard let product = primaryProduct, let subscription = product.subscription else {
            isEligibleForIntroOffer = false
            if let entitlement = await currentEntitlementTransaction() {
                accessState = accessState(from: entitlement)
            } else {
                accessState = .notSubscribed
            }
            return
        }

        // StoreKit eligibility can be async.
        isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer

        do {
            let statuses = try await subscription.status
            if let best = bestStatus(from: statuses) {
                accessState = accessState(from: best)
                return
            }
        } catch {
            #if DEBUG
            print("⚠️ Failed to fetch subscription status: \(error.localizedDescription)")
            #endif
        }

        // Fallback: current entitlement transaction (works even if status fetch fails).
        if let entitlement = await currentEntitlementTransaction() {
            accessState = accessState(from: entitlement)
        } else {
            accessState = .notSubscribed
        }
    }

    // MARK: - Helpers

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            guard let self else { return }

            for await result in StoreKit.Transaction.updates {
                switch result {
                case .verified(let transaction):
                    // Update first, finish afterwards.
                    await self.updateAccessState()
                    await transaction.finish()
                case .unverified:
                    #if DEBUG
                    print("❌ Transaction unverified")
                    #endif
                }
            }
        }
    }

    private func currentEntitlementTransaction() async -> StoreKit.Transaction? {
        for await result in StoreKit.Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               productIds.contains(transaction.productID) {
                return transaction
            }
        }
        return nil
    }

    private func bestStatus(from statuses: [Product.SubscriptionInfo.Status]) -> Product.SubscriptionInfo.Status? {
        let sorted = statuses.sorted(by: { (lhs: Product.SubscriptionInfo.Status, rhs: Product.SubscriptionInfo.Status) -> Bool in
            let leftPriority = statusPriority(lhs.state)
            let rightPriority = statusPriority(rhs.state)

            if leftPriority != rightPriority {
                return leftPriority > rightPriority
            }

            // Prefer comparing verified transaction expirations; treat unverified as very old.
            let leftExpiry = (try? lhs.transaction.payloadValue.expirationDate) ?? Date.distantPast
            let rightExpiry = (try? rhs.transaction.payloadValue.expirationDate) ?? Date.distantPast
            return leftExpiry > rightExpiry
        })

        return sorted.first
    }

    private func statusPriority(_ state: Product.SubscriptionInfo.RenewalState) -> Int {
        switch state {
        case .subscribed:
            return 5
        case .inGracePeriod:
            return 4
        case .inBillingRetryPeriod:
            return 3
        case .expired:
            return 2
        case .revoked:
            return 1
        // Treat any new/unknown state as “active” for forward compatibility.
        default:
            return 5
        }
    }

    private func accessState(from status: Product.SubscriptionInfo.Status) -> AccessState {
        switch status.state {
        case .subscribed:
            // Once purchased, always show as subscribed (not trial countdown)
            return .subscribed
        case .inGracePeriod:
            return .gracePeriod
        case .inBillingRetryPeriod:
            return .billingRetry
        case .expired:
            return .expired
        case .revoked:
            return .revoked
        default:
            // Assume access for unknown states (more user-friendly and matches StoreKit's forward-compat needs).
            return .subscribed
        }
    }

    private func accessState(from transaction: StoreKit.Transaction) -> AccessState {
        // Once purchased, always show as subscribed (not trial countdown)
        return .subscribed
    }

    private func trialDaysRemaining(from transaction: StoreKit.Transaction) -> Int? {
        // NOTE: offerType is deprecated, but still works across OS versions; we can modernize later by checking `transaction.offer`.
        guard transaction.offer?.type == .introductory,
              let expirationDate = transaction.expirationDate else {
            return nil
        }

        let now = Date()
        let components = Calendar.current.dateComponents([.day], from: now, to: expirationDate)
        let days = components.day ?? 0
        return max(0, days)
    }

    func subscriptionPeriodText(for product: Product) -> String? {
        guard let period = product.subscription?.subscriptionPeriod else {
            return nil
        }

        switch period.unit {
        case .day:
            return period.value == 1 ? "day" : "\(period.value) days"
        case .week:
            return period.value == 1 ? "week" : "\(period.value) weeks"
        case .month:
            return period.value == 1 ? "month" : "\(period.value) months"
        case .year:
            return period.value == 1 ? "year" : "\(period.value) years"
        @unknown default:
            return nil
        }
    }
}
