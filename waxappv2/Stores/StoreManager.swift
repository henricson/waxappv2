//
//  StoreManager.swift
//  waxappv2
//
//  Created by Herman Henriksen on 10/01/2026.
//

import Foundation
import StoreKit

nonisolated enum AccessState: Equatable {
  case loading
  case notSubscribed
  case trialActive(daysLeft: Int)
  case subscribed
  /// One-time purchase: access that never expires.
  case lifetime
  case gracePeriod
  case billingRetry
  case expired
  case revoked

  var hasAccess: Bool {
    switch self {
    case .trialActive, .subscribed, .lifetime, .gracePeriod, .billingRetry:
      return true
    case .loading, .notSubscribed, .expired, .revoked:
      return false
    }
  }
}

@MainActor
@Observable final class StoreManager {
  private static let yearlyProductId = "com.squarewave.getgrip.yearly"
  private static let monthlyProductId = "com.squarewave.getgrip.monthly"
  /// Non-consumable that unlocks the app for good, sold beside the subscriptions.
  private static let lifetimeProductId = "com.squarewave.getgrip.lifetime"

  var yearlyProduct: Product?
  var monthlyProduct: Product?
  var lifetimeProduct: Product?
  var productsError: String?
  var isPurchasing = false
  var purchaseError: String?
  var accessState: AccessState = .loading
  var isInitialized = false
  var isEligibleForIntroOffer = false
  /// True when someone owns the lifetime unlock but a subscription is still
  /// renewing — they are paying twice and should be told.
  var hasRedundantSubscription = false

  var primaryProduct: Product? { yearlyProduct ?? monthlyProduct }
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
    // Screenshots and UI tests pin access so StoreKit never gets a say.
    if DemoMode.isEnabled {
      applyDemoAccess()
      return
    }
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
      if yearlyProduct != nil || monthlyProduct != nil || lifetimeProduct != nil { return }
      if attempt < maxAttempts {
        try? await Task.sleep(for: .seconds(Double(attempt * attempt)))
      }
    }
  }

  func subscriptionPeriodText(for product: Product) -> String? {
    guard let period = product.subscription?.subscriptionPeriod else { return nil }
    switch period.unit {
    case .day: return period.value == 1 ? String(localized: "day") : String(localized: "\(period.value) days")
    case .week: return period.value == 1 ? String(localized: "week") : String(localized: "\(period.value) weeks")
    case .month: return period.value == 1 ? String(localized: "month") : String(localized: "\(period.value) months")
    case .year: return period.value == 1 ? String(localized: "year") : String(localized: "\(period.value) years")
    @unknown default: return nil
    }
  }

  // MARK: - Private

  func updateAccessState() async {
    if yearlyProduct == nil && monthlyProduct == nil && lifetimeProduct == nil { await fetchProducts() }

    // Entitlement is the source of truth for access right now.
    let yearlyEntitlement = await currentEntitlement(productID: Self.yearlyProductId)
    let monthlyEntitlement = await currentEntitlement(productID: Self.monthlyProductId)
    let lifetimeEntitlement = await currentEntitlement(productID: Self.lifetimeProductId)

    // A lifetime unlock outranks any subscription state. A refunded one is
    // ignored, so the subscription (if any) decides instead.
    if let lifetime = lifetimeEntitlement, lifetime.revocationDate == nil {
      accessState = .lifetime
      isEligibleForIntroOffer = false
      let renewing = [yearlyEntitlement, monthlyEntitlement].compactMap { $0 }
      hasRedundantSubscription = renewing.contains { $0.revocationDate == nil }
      return
    }
    hasRedundantSubscription = false

    if let entitlement = yearlyEntitlement ?? monthlyEntitlement {
      accessState = accessStateFromEntitlement(entitlement)
      // If they currently have access, intro offers shouldn't be shown.
      isEligibleForIntroOffer = false
      return
    }

    // No current entitlement. Use subscription status for messaging.
    // Trial eligibility applies only to the yearly product.
    if let subscription = yearlyProduct?.subscription {
      isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
    } else {
      isEligibleForIntroOffer = false
    }

    var allStatuses: [Product.SubscriptionInfo.Status] = []
    if let ys = try? await yearlyProduct?.subscription?.status {
      allStatuses.append(contentsOf: ys ?? [])
    }
    if let ms = try? await monthlyProduct?.subscription?.status {
      allStatuses.append(contentsOf: ms ?? [])
    }

    if let best = allStatuses.max(by: { priority($0.state) < priority($1.state) }) {
      accessState = mapState(best.state)
    } else {
      accessState = .notSubscribed
    }
  }

  private func fetchProducts() async {
    do {
      let products = try await Product.products(
        for: [Self.yearlyProductId, Self.monthlyProductId, Self.lifetimeProductId])
      print("StoreKit: fetched \(products.count) products")
      for p in products {
        print("  - \(p.id): \(p.displayName)")
        switch p.id {
        case Self.yearlyProductId:
          yearlyProduct = p
        case Self.monthlyProductId:
          monthlyProduct = p
        case Self.lifetimeProductId:
          lifetimeProduct = p
        default:
          break
        }
      }
      productsError =
        (yearlyProduct == nil && monthlyProduct == nil && lifetimeProduct == nil)
        ? "No products found" : nil
    } catch {
      print("StoreKit fetch error: \(error)")
      productsError = error.localizedDescription
    }
  }

  private func hasEntitlement() async -> Bool {
    let hasYearly = await currentEntitlement(productID: Self.yearlyProductId) != nil
    let hasMonthly = await currentEntitlement(productID: Self.monthlyProductId) != nil
    let hasLifetime = await currentEntitlement(productID: Self.lifetimeProductId) != nil
    return hasYearly || hasMonthly || hasLifetime
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

  func accessStateFromEntitlement(_ transaction: Transaction) -> AccessState {
    // Refund/revocation should always remove access.
    if transaction.revocationDate != nil {
      return .revoked
    }

    // Show trial if it's a subscription and marked as an intro offer.
    if transaction.productType == .autoRenewable,
       (transaction.offer?.type == .introductory),
       let expiration = transaction.expirationDate {
      let now = Date()
      guard expiration > now else { return .subscribed }
      // Count whole calendar days between the two dates rather than
      // 86 400-second chunks: a span crossing a daylight-saving change is 23
      // or 25 hours long, which made a 14-day trial report 15. Comparing
      // start-of-day also keeps "expires in 23 hours" at 1 day rather than 0.
      let calendar = Calendar.current
      let daysLeft =
        calendar.dateComponents(
          [.day],
          from: calendar.startOfDay(for: now),
          to: calendar.startOfDay(for: expiration)
        ).day ?? 0
      return .trialActive(daysLeft: max(1, daysLeft))
    }

    return .subscribed
  }

  func priority(_ state: Product.SubscriptionInfo.RenewalState) -> Int {
    switch state {
    case .subscribed: return 5
    case .inGracePeriod: return 4
    case .inBillingRetryPeriod: return 3
    case .expired: return 2
    case .revoked: return 1
    default: return 0
    }
  }

  func mapState(_ state: Product.SubscriptionInfo.RenewalState) -> AccessState {
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


// MARK: - Demo mode

extension StoreManager {
  /// Grants access without touching StoreKit, for App Store screenshots and
  /// UI tests. Only ever called when `DemoMode.isEnabled`.
  func applyDemoAccess() {
    accessState = .subscribed
    isInitialized = true
    isEligibleForIntroOffer = false
  }
}
