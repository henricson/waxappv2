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
  private func debugLog(_ message: String) {
    print("[StoreManager] \(message)")
  }
  
  private static let productId = "com.squarewave.getgrip.annual"

  var product: Product?
  var productsError: String?
  var isPurchasing = false
  var purchaseError: String?
  var accessState: AccessState = .loading
  var isInitialized = false
  var isEligibleForIntroOffer = false

  nonisolated(unsafe) var transactionListener: Task<Void, Never>?

  var primaryProduct: Product? { product }
  var hasAccess: Bool { accessState.hasAccess }
  var trialDaysRemaining: Int? {
    if case .trialActive(let days) = accessState { return days }
    return nil
  }

  init() {
    transactionListener = Task { [weak self] in
      for await result in Transaction.updates {
        self?.debugLog("Received transaction update")
        if case .verified(let transaction) = result {
          self?.debugLog("Verified transaction: id=\(transaction.id), productID=\(transaction.productID)")
          await self?.updateAccessState()
          await transaction.finish()
          self?.debugLog("Finished transaction: id=\(transaction.id)")
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
    debugLog("refreshAll(force: \(force)) called. isInitialized=\(isInitialized)")
    if isInitialized && !force {
      debugLog("Already initialized; updating access state only")
      await updateAccessState()
      return
    }
    await fetchProducts()
    await updateAccessState()
    debugLog("Finished refreshAll: product=\(String(describing: product)), accessState=\(accessState)")
    isInitialized = true
  }

  func purchase(_ product: Product) async {
    debugLog("Attempting purchase for productID=\(product.id)")
    guard !isPurchasing else {
      debugLog("Purchase already in progress; ignoring new request")
      return
    }

    isPurchasing = true
    purchaseError = nil
    debugLog("Starting purchase...")
    defer { isPurchasing = false }

    do {
      let result = try await product.purchase()
      debugLog("Purchase call returned a result")
      if case .success(.verified(let transaction)) = result {
        debugLog("Purchase success verified: id=\(transaction.id), productID=\(transaction.productID)")
        await updateAccessState()
        await transaction.finish()
        debugLog("Transaction finished after purchase: id=\(transaction.id)")
      } else if case .success(.unverified) = result {
        purchaseError = "Purchase verification failed."
        debugLog("Purchase success but unverified signature")
      } else if case .userCancelled = result {
        debugLog("Purchase cancelled by user")
      }
    } catch {
      purchaseError = error.localizedDescription
      debugLog("Purchase failed with error: \(error.localizedDescription)")
    }
  }

  func restorePurchases() async {
    debugLog("Restore purchases initiated")
    purchaseError = nil
    do {
      try await AppStore.sync()
      debugLog("AppStore.sync completed successfully")
    } catch {
      purchaseError = error.localizedDescription
      debugLog("Restore failed with error: \(error.localizedDescription)")
    }
    await updateAccessState()
    debugLog("Restore completed. accessState=\(accessState)")
  }

  func retryFetchProducts(maxAttempts: Int = 3) async {
    debugLog("retryFetchProducts(maxAttempts: \(maxAttempts))")
    for attempt in 1...maxAttempts {
      await fetchProducts()
      debugLog("Attempt #\(attempt): product=\(String(describing: product)) error=\(String(describing: productsError))")
      if product != nil { return }
      if attempt < maxAttempts {
        debugLog("Retrying fetch in \(attempt * attempt) seconds...")
        try? await Task.sleep(for: .seconds(Double(attempt * attempt)))
      }
    }
  }

  func subscriptionPeriodText(for product: Product) -> String? {
    guard let period = product.subscription?.subscriptionPeriod else {
      debugLog("No subscription period available for productID=\(product.id)")
      return nil
    }
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
    debugLog("updateAccessState() called")
    if product == nil { await fetchProducts() }
    debugLog("Product after fetch: \(String(describing: product))")

    guard let product, let subscription = product.subscription else {
      debugLog("No product or subscription info available; checking entitlement")
      accessState = await hasEntitlement() ? .subscribed : .notSubscribed
      isEligibleForIntroOffer = false
      return
    }

    isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
    debugLog("isEligibleForIntroOffer=\(isEligibleForIntroOffer)")

    debugLog("Fetching subscription.status ...")
    if let statuses = try? await subscription.status,
       let best = statuses.max(by: { priority($0.state) < priority($1.state) }) {
      debugLog("Best subscription state=\(best.state)")
      accessState = mapState(best.state)
    } else {
      debugLog("Failed to fetch subscription.status; falling back to entitlement check")
      accessState = await hasEntitlement() ? .subscribed : .notSubscribed
    }
    debugLog("updateAccessState() resolved accessState=\(accessState)")
  }

  private func fetchProducts() async {
    debugLog("Fetching products for id=\(Self.productId)")
    do {
      let products = try await Product.products(for: [Self.productId])
      product = products.first
      debugLog("Fetched product: \(String(describing: product))")
      productsError = product == nil ? "No products found" : nil
      if let productsError {
        debugLog("Products error: \(productsError)")
      }
      isEligibleForIntroOffer = await product?.subscription?.isEligibleForIntroOffer ?? false
      debugLog("isEligibleForIntroOffer (from fetch) = \(isEligibleForIntroOffer)")
    } catch {
      productsError = error.localizedDescription
      debugLog("Products error: \(productsError ?? "unknown error")")
    }
  }

  private func hasEntitlement() async -> Bool {
    debugLog("Checking current entitlements for productId=\(Self.productId)")
    for await result in Transaction.currentEntitlements {
      if case .verified(let t) = result, t.productID == Self.productId {
        debugLog("Found verified entitlement: transactionID=\(t.id), productID=\(t.productID)")
        return true
      }
    }
    debugLog("No entitlement found for productId=\(Self.productId)")
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

