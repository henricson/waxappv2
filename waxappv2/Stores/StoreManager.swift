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
  private static let productId = "com.squarewave.no.waxappv2.annual"

  var product: Product?
  var productsError: String?
  var isPurchasing = false
  var purchaseError: String?
  var accessState: AccessState = .loading
  var isInitialized = false
  var isEligibleForIntroOffer = false

    private nonisolated var transactionListener: Task<Void, Never>?

  var primaryProduct: Product? { product }
  var hasAccess: Bool { accessState.hasAccess }
  var trialDaysRemaining: Int? {
    if case .trialActive(let days) = accessState { return days }
    return nil
  }

  init() {
    transactionListener = Task { [weak self] in
      for await result in Transaction.updates {
        if case .verified(let transaction) = result {
          await self?.updateAccessState()
          await transaction.finish()
        }
      }
    }
    Task { await refreshAll() }
  }

  deinit {
    transactionListener?.cancel()
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
      if case .success(.verified(let transaction)) = result {
        await updateAccessState()
        await transaction.finish()
      } else if case .success(.unverified) = result {
        purchaseError = "Purchase verification failed."
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
    await updateAccessState()
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

    isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer

    if let statuses = try? await subscription.status,
       let best = statuses.max(by: { priority($0.state) < priority($1.state) }) {
      accessState = mapState(best.state)
    } else {
      accessState = await hasEntitlement() ? .subscribed : .notSubscribed
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
    for await result in Transaction.currentEntitlements {
      if case .verified(let t) = result, t.productID == Self.productId {
        return true
      }
    }
    return false
  }

  private func priority(_ state: Product.SubscriptionInfo.RenewalState) -> Int {
    switch state {
    case .subscribed: return 5
    case .inGracePeriod: return 4
    case .inBillingRetryPeriod: return 3
    case .expired: return 2
    case .revoked: return 1
    default: return 5
    }
  }

  private func mapState(_ state: Product.SubscriptionInfo.RenewalState) -> AccessState {
    switch state {
    case .subscribed: return .subscribed
    case .inGracePeriod: return .gracePeriod
    case .inBillingRetryPeriod: return .billingRetry
    case .expired: return .expired
    case .revoked: return .revoked
    default: return .subscribed
    }
  }
}
