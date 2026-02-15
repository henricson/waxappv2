//
//  StoreManager.swift
//  waxappv2
//
//  Created by Herman Henriksen on 10/01/2026.
//

import Foundation
import StoreKit

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
  private static let productId = "com.squarewave.getgrip.annual"

  var product: Product?
  var productsError: String?
  var isPurchasing = false
  var purchaseError: String?
  var accessState: AccessState = .loading
  var isInitialized = false
  var isEligibleForIntroOffer = false

  var primaryProduct: Product? { product }
  var hasAccess: Bool { accessState.hasAccess }
  var trialDaysRemaining: Int? {
    if case .trialActive(let days) = accessState { return days }
    return nil
  }

  init() {
    // Listen for transaction updates (renewals, purchases from other devices, etc.)
    Task { [weak self] in
      for await result in Transaction.updates {
        guard case .verified(let transaction) = result else { continue }
        await self?.refreshAll(force: true)
        await transaction.finish()
      }
    }
    Task { await refreshAll() }
  }

  // MARK: - Public API

  func refreshAll(force: Bool = false) async {
    if isInitialized && !force {
      await updateAccessState()
      return
    }
    await fetchProducts()
    await updateAccessState()
    isInitialized = true
  }

  func purchase(_ product: Product) async {
    guard !isPurchasing else { return }

    isPurchasing = true
    purchaseError = nil
    defer { isPurchasing = false }

    do {
      let result = try await product.purchase()
      switch result {
      case .success(let verificationResult):
        switch verificationResult {
        case .verified(let transaction):
          // Finishing first prevents repeat deliveries, then sync + refresh to
          // reliably pick up renewals/changes across devices.
          await transaction.finish()
          try? await AppStore.sync()
          await refreshAll(force: true)

        case .unverified:
          purchaseError = "Purchase verification failed." // keep generic
        }

      case .pending:
        purchaseError = "Purchase pending approval or payment confirmation."

      case .userCancelled:
        // Not an error; user backed out.
        purchaseError = nil

      @unknown default:
        purchaseError = "Unknown purchase result."
      }
    } catch {
      purchaseError = error.localizedDescription
    }
  }

  func restorePurchases() async {
    purchaseError = nil
    do {
      try await AppStore.sync()
    } catch {
      purchaseError = error.localizedDescription
    }
    await refreshAll(force: true)
  }

  func retryFetchProducts(maxAttempts: Int = 3) async {
    for attempt in 1...maxAttempts {
      await fetchProducts()
      if product != nil { return }
      if attempt < maxAttempts {
        try? await Task.sleep(for: .seconds(Double(attempt * attempt)))
      }
    }
  }

  func subscriptionPeriodText(for product: Product) -> String? {
    guard let period = product.subscription?.subscriptionPeriod else { return nil }
    switch period.unit {
    case .day: return period.value == 1 ? "day" : "\(period.value) days"
    case .week: return period.value == 1 ? "week" : "\(period.value) weeks"
    case .month: return period.value == 1 ? "month" : "\(period.value) months"
    case .year: return period.value == 1 ? "year" : "\(period.value) years"
    @unknown default: return nil
    }
  }

  // MARK: - Private

  func updateAccessState() async {
    if product == nil { await fetchProducts() }

    guard let product, let subscription = product.subscription else {
      accessState = await hasEntitlement() ? .subscribed : .notSubscribed
      isEligibleForIntroOffer = false
      return
    }

    // Entitlement is the source of truth for access right now.
    let entitlement = await currentEntitlement(productID: Self.productId)
    if let entitlement {
      accessState = accessStateFromEntitlement(entitlement)
      // If they currently have access, intro offers shouldn't be shown.
      isEligibleForIntroOffer = false
      return
    }

    // No current entitlement. Use subscription status for messaging.
    isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer

    if let statuses = try? await subscription.status,
       let best = statuses.max(by: { priority($0.state) < priority($1.state) }) {
      accessState = mapState(best.state)
    } else {
      accessState = .notSubscribed
    }
  }

  private func fetchProducts() async {
    do {
      let products = try await Product.products(for: [Self.productId])
      product = products.first
      productsError = product == nil ? "No products found" : nil
      isEligibleForIntroOffer = await product?.subscription?.isEligibleForIntroOffer ?? false
    } catch {
      productsError = error.localizedDescription
    }
  }

  private func hasEntitlement() async -> Bool {
    return await currentEntitlement(productID: Self.productId) != nil
  }

  private func currentEntitlement(productID: String) async -> Transaction? {
    for await result in Transaction.currentEntitlements {
      guard case .verified(let t) = result else { continue }
      if t.productID == productID {
        return t
      }
    }
    return nil
  }

  private func accessStateFromEntitlement(_ transaction: Transaction) -> AccessState {
    // Refund/revocation should always remove access.
    if transaction.revocationDate != nil {
      return .revoked
    }

    // Show trial if it's a subscription and marked as an intro offer.
    if transaction.productType == .autoRenewable,
       (transaction.offer?.type == .introductory),
       let expiration = transaction.expirationDate {
      let daysLeft = max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0)
      return .trialActive(daysLeft: daysLeft)
    }

    return .subscribed
  }

  private func priority(_ state: Product.SubscriptionInfo.RenewalState) -> Int {
    switch state {
    case .subscribed: return 5
    case .inGracePeriod: return 4
    case .inBillingRetryPeriod: return 3
    case .expired: return 2
    case .revoked: return 1
    default: return 0
    }
  }

  private func mapState(_ state: Product.SubscriptionInfo.RenewalState) -> AccessState {
    switch state {
    case .subscribed: return .subscribed
    case .inGracePeriod: return .gracePeriod
    case .inBillingRetryPeriod: return .billingRetry
    case .expired: return .expired
    case .revoked: return .revoked
    default: return .notSubscribed
    }
  }
}
