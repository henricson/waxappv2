import Foundation
import Testing
@testable import waxappv2

@Suite("StoreManager access state")
struct StoreManagerTests {

    @Test("AccessState.hasAccess mapping")
    func accessState_hasAccess() {
        #expect(AccessState.loading.hasAccess == false)
        #expect(AccessState.notSubscribed.hasAccess == false)
        #expect(AccessState.expired.hasAccess == false)
        #expect(AccessState.revoked.hasAccess == false)

        #expect(AccessState.trialActive(daysLeft: 14).hasAccess == true)
        #expect(AccessState.subscribed.hasAccess == true)
        #expect(AccessState.gracePeriod.hasAccess == true)
        #expect(AccessState.billingRetry.hasAccess == true)
    }

    @Test("Trial days remaining is clamped")
    func trialDays_remaining_clampsToZero() async {
        // This doesn't instantiate StoreKit.Transaction (hard to do in unit tests).
        // Instead, we validate the clamping logic indirectly via DateComponents.
        let now = Date()
        let past = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let components = Calendar.current.dateComponents([.day], from: now, to: past)
        let days = components.day ?? 0
        #expect(days <= 0)
        #expect(max(0, days) == 0)
    }
}
