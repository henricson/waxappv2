import Foundation
import StoreKit
import Testing

@testable import waxappv2

// MARK: - AccessState Tests

@Suite("AccessState")
struct AccessStateTests {

  @Test("hasAccess is true for states that grant access")
  func hasAccess_grantingStates() {
    #expect(AccessState.trialActive(daysLeft: 14).hasAccess == true)
    #expect(AccessState.trialActive(daysLeft: 0).hasAccess == true)
    #expect(AccessState.subscribed.hasAccess == true)
    #expect(AccessState.gracePeriod.hasAccess == true)
    #expect(AccessState.billingRetry.hasAccess == true)
  }

  @Test("hasAccess is false for states that deny access")
  func hasAccess_denyingStates() {
    #expect(AccessState.loading.hasAccess == false)
    #expect(AccessState.notSubscribed.hasAccess == false)
    #expect(AccessState.expired.hasAccess == false)
    #expect(AccessState.revoked.hasAccess == false)
  }

  @Test("trialActive with various day counts all grant access")
  func trialActive_variousDays() {
    for days in [0, 1, 7, 14, 30, 365] {
      #expect(AccessState.trialActive(daysLeft: days).hasAccess == true,
              "trialActive(daysLeft: \(days)) should have access")
    }
  }

  @Test("Equatable conformance")
  func equatable() {
    #expect(AccessState.loading == AccessState.loading)
    #expect(AccessState.subscribed == AccessState.subscribed)
    #expect(AccessState.notSubscribed == AccessState.notSubscribed)
    #expect(AccessState.expired == AccessState.expired)
    #expect(AccessState.revoked == AccessState.revoked)
    #expect(AccessState.gracePeriod == AccessState.gracePeriod)
    #expect(AccessState.billingRetry == AccessState.billingRetry)
    #expect(AccessState.trialActive(daysLeft: 14) == AccessState.trialActive(daysLeft: 14))
    #expect(AccessState.trialActive(daysLeft: 7) != AccessState.trialActive(daysLeft: 14))
    #expect(AccessState.loading != AccessState.subscribed)
  }
}

// MARK: - StoreManager Computed Property Tests

@Suite("StoreManager computed properties")
struct StoreManagerComputedPropertyTests {

  @Test("trialDaysRemaining returns days when trialActive")
  @MainActor
  func trialDaysRemaining_active() {
    let store = StoreManager()
    store.accessState = .trialActive(daysLeft: 10)
    #expect(store.trialDaysRemaining == 10)
  }

  @Test("trialDaysRemaining returns nil when not trial")
  @MainActor
  func trialDaysRemaining_notTrial() {
    let store = StoreManager()

    store.accessState = .subscribed
    #expect(store.trialDaysRemaining == nil)

    store.accessState = .loading
    #expect(store.trialDaysRemaining == nil)

    store.accessState = .notSubscribed
    #expect(store.trialDaysRemaining == nil)

    store.accessState = .expired
    #expect(store.trialDaysRemaining == nil)

    store.accessState = .gracePeriod
    #expect(store.trialDaysRemaining == nil)
  }

  @Test("hasAccess reflects accessState")
  @MainActor
  func hasAccess_mirrors_accessState() {
    let store = StoreManager()

    store.accessState = .subscribed
    #expect(store.hasAccess == true)

    store.accessState = .notSubscribed
    #expect(store.hasAccess == false)

    store.accessState = .trialActive(daysLeft: 3)
    #expect(store.hasAccess == true)

    store.accessState = .revoked
    #expect(store.hasAccess == false)
  }

  @Test("trialDaysRemaining is 0 when trial expired same day")
  @MainActor
  func trialDaysRemaining_zero() {
    let store = StoreManager()
    store.accessState = .trialActive(daysLeft: 0)
    #expect(store.trialDaysRemaining == 0)
  }
}

// MARK: - RenewalState Priority Tests

@Suite("RenewalState priority ordering")
struct RenewalStatePriorityTests {

  @Test("subscribed has highest priority")
  @MainActor
  func subscribed_highest() {
    let store = StoreManager()
    let subscribedPriority = store.priority(.subscribed)
    #expect(subscribedPriority > store.priority(.inGracePeriod))
    #expect(subscribedPriority > store.priority(.inBillingRetryPeriod))
    #expect(subscribedPriority > store.priority(.expired))
    #expect(subscribedPriority > store.priority(.revoked))
  }

  @Test("gracePeriod has second highest priority")
  @MainActor
  func gracePeriod_second() {
    let store = StoreManager()
    #expect(store.priority(.inGracePeriod) > store.priority(.inBillingRetryPeriod))
    #expect(store.priority(.inGracePeriod) > store.priority(.expired))
    #expect(store.priority(.inGracePeriod) > store.priority(.revoked))
  }

  @Test("billingRetry beats expired and revoked")
  @MainActor
  func billingRetry_beats_expired_revoked() {
    let store = StoreManager()
    #expect(store.priority(.inBillingRetryPeriod) > store.priority(.expired))
    #expect(store.priority(.inBillingRetryPeriod) > store.priority(.revoked))
  }

  @Test("expired beats revoked")
  @MainActor
  func expired_beats_revoked() {
    let store = StoreManager()
    #expect(store.priority(.expired) > store.priority(.revoked))
  }

  @Test("priority values are strictly ordered")
  @MainActor
  func strict_ordering() {
    let store = StoreManager()
    let values = [
      store.priority(.revoked),
      store.priority(.expired),
      store.priority(.inBillingRetryPeriod),
      store.priority(.inGracePeriod),
      store.priority(.subscribed)
    ]
    // Each value should be strictly greater than the previous
    for i in 1..<values.count {
      #expect(values[i] > values[i - 1],
              "Priority at index \(i) should be greater than \(i - 1)")
    }
  }
}

// MARK: - MapState Tests

@Suite("RenewalState to AccessState mapping")
struct MapStateTests {

  @Test("subscribed maps to .subscribed")
  @MainActor
  func subscribed() {
    let store = StoreManager()
    #expect(store.mapState(.subscribed) == .subscribed)
  }

  @Test("inGracePeriod maps to .gracePeriod")
  @MainActor
  func gracePeriod() {
    let store = StoreManager()
    #expect(store.mapState(.inGracePeriod) == .gracePeriod)
  }

  @Test("inBillingRetryPeriod maps to .billingRetry")
  @MainActor
  func billingRetry() {
    let store = StoreManager()
    #expect(store.mapState(.inBillingRetryPeriod) == .billingRetry)
  }

  @Test("expired maps to .expired")
  @MainActor
  func expired() {
    let store = StoreManager()
    #expect(store.mapState(.expired) == .expired)
  }

  @Test("revoked maps to .revoked")
  @MainActor
  func revoked() {
    let store = StoreManager()
    #expect(store.mapState(.revoked) == .revoked)
  }
}

// MARK: - Trial Days Calculation Tests

@Suite("Trial days remaining calculation (ceil-based)")
struct TrialDaysCalculationTests {

  /// Helper matching the production logic in accessStateFromEntitlement
  private func daysLeft(from now: Date, to expiration: Date) -> Int {
    guard expiration > now else { return 0 }
    let secondsLeft = expiration.timeIntervalSince(now)
    return max(1, Int(ceil(secondsLeft / 86_400)))
  }

  @Test("Exactly 10 days gives 10")
  func futureExpiration() {
    let now = Date()
    let expiration = Calendar.current.date(byAdding: .day, value: 10, to: now)!
    #expect(daysLeft(from: now, to: expiration) == 10)
  }

  @Test("Past expiration gives zero")
  func pastExpiration() {
    let now = Date()
    let expiration = Calendar.current.date(byAdding: .day, value: -3, to: now)!
    #expect(daysLeft(from: now, to: expiration) == 0)
  }

  @Test("Same instant gives zero")
  func sameDayExpiration() {
    let now = Date()
    #expect(daysLeft(from: now, to: now) == 0)
  }

  @Test("Exactly 1 day gives 1")
  func oneDayRemaining() {
    let now = Date()
    let expiration = Calendar.current.date(byAdding: .day, value: 1, to: now)!
    #expect(daysLeft(from: now, to: expiration) == 1)
  }

  @Test("Exactly 14 days gives 14")
  func fourteenDayTrial() {
    let now = Date()
    let expiration = Calendar.current.date(byAdding: .day, value: 14, to: now)!
    #expect(daysLeft(from: now, to: expiration) == 14)
  }

  @Test("A few hours rounds up to 1 day")
  func partialDayRoundsUp() {
    let now = Date()
    let expiration = now.addingTimeInterval(3 * 3600) // 3 hours
    #expect(daysLeft(from: now, to: expiration) == 1)
  }

  @Test("5 minutes left (sandbox trial) rounds up to 1 day")
  func sandboxTrialRoundsUp() {
    let now = Date()
    let expiration = now.addingTimeInterval(5 * 60) // 5 minutes
    #expect(daysLeft(from: now, to: expiration) == 1)
  }

  @Test("1.5 days rounds up to 2")
  func oneAndHalfDays() {
    let now = Date()
    let expiration = now.addingTimeInterval(1.5 * 86_400)
    #expect(daysLeft(from: now, to: expiration) == 2)
  }

  @Test("Far past returns zero")
  func farPast() {
    let now = Date()
    let past = now.addingTimeInterval(-100 * 86_400)
    #expect(daysLeft(from: now, to: past) == 0)
  }
}

// MARK: - StoreManager Initial State Tests

@Suite("StoreManager initial state")
struct StoreManagerInitialStateTests {

  @Test("Default state is loading")
  @MainActor
  func defaultState() {
    let store = StoreManager()
    #expect(store.accessState == .loading)
  }

  @Test("Not purchasing initially")
  @MainActor
  func notPurchasing() {
    let store = StoreManager()
    #expect(store.isPurchasing == false)
  }

  @Test("No purchase error initially")
  @MainActor
  func noPurchaseError() {
    let store = StoreManager()
    #expect(store.purchaseError == nil)
  }

  @Test("Not eligible for intro offer initially")
  @MainActor
  func notEligibleInitially() {
    let store = StoreManager()
    #expect(store.isEligibleForIntroOffer == false)
  }

  @Test("No product initially")
  @MainActor
  func noProduct() {
    let store = StoreManager()
    #expect(store.product == nil)
    #expect(store.primaryProduct == nil)
  }

  @Test("hasAccess is false when loading")
  @MainActor
  func noAccessWhenLoading() {
    let store = StoreManager()
    #expect(store.hasAccess == false)
  }
}

// MARK: - AccessState Transition Tests

@Suite("AccessState transitions")
struct AccessStateTransitionTests {

  @Test("Setting accessState updates hasAccess immediately")
  @MainActor
  func immediateUpdate() {
    let store = StoreManager()
    #expect(store.hasAccess == false)

    store.accessState = .subscribed
    #expect(store.hasAccess == true)

    store.accessState = .expired
    #expect(store.hasAccess == false)

    store.accessState = .trialActive(daysLeft: 7)
    #expect(store.hasAccess == true)

    store.accessState = .revoked
    #expect(store.hasAccess == false)
  }

  @Test("Transitioning through all states")
  @MainActor
  func allTransitions() {
    let store = StoreManager()
    let states: [(AccessState, Bool)] = [
      (.loading, false),
      (.notSubscribed, false),
      (.trialActive(daysLeft: 14), true),
      (.trialActive(daysLeft: 0), true),
      (.subscribed, true),
      (.gracePeriod, true),
      (.billingRetry, true),
      (.expired, false),
      (.revoked, false),
    ]

    for (state, expectedAccess) in states {
      store.accessState = state
      #expect(store.hasAccess == expectedAccess,
              "State \(state) should have hasAccess=\(expectedAccess)")
    }
  }

  @Test("Trial to expired removes access")
  @MainActor
  func trialToExpired() {
    let store = StoreManager()
    store.accessState = .trialActive(daysLeft: 1)
    #expect(store.hasAccess == true)

    store.accessState = .expired
    #expect(store.hasAccess == false)
    #expect(store.trialDaysRemaining == nil)
  }

  @Test("Grace period still has access")
  @MainActor
  func gracePeriodAccess() {
    let store = StoreManager()
    store.accessState = .subscribed
    #expect(store.hasAccess == true)

    store.accessState = .gracePeriod
    #expect(store.hasAccess == true, "Grace period should still grant access")
  }

  @Test("Billing retry still has access")
  @MainActor
  func billingRetryAccess() {
    let store = StoreManager()
    store.accessState = .billingRetry
    #expect(store.hasAccess == true, "Billing retry should still grant access")
  }
}
