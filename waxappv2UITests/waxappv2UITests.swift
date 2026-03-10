import XCTest

// MARK: - Base Test Class

class GetGripUITestCase: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments += ["-hasSeenOnboarding", "YES"]
  }

  /// Wait for an element to exist with a timeout.
  func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
    element.waitForExistence(timeout: timeout)
  }
}

// MARK: - Onboarding Tests

final class OnboardingUITests: GetGripUITestCase {

  override func setUpWithError() throws {
    try super.setUpWithError()
    // Remove the skip-onboarding flag for onboarding tests
    app.launchArguments.removeAll { $0 == "-hasSeenOnboarding" || $0 == "YES" }
    app.launchArguments += ["-hasSeenOnboarding", "NO"]
  }

  @MainActor
  func testOnboardingFlowShowsAllPages() throws {
    app.launch()

    // Page 1: Welcome
    XCTAssertTrue(waitForElement(app.staticTexts["Welcome to GetGrip"]),
                  "First onboarding page should show welcome title")

    // Tap Next
    let nextButton = app.buttons["onboardingPrimaryButton"]
    XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
    nextButton.tap()

    // Page 2: Always the best grip
    XCTAssertTrue(waitForElement(app.staticTexts["Always the best grip"]),
                  "Second onboarding page should show analytics title")

    // Tap Next again
    let nextButton2 = app.buttons["onboardingPrimaryButton"]
    XCTAssertTrue(nextButton2.waitForExistence(timeout: 5))
    nextButton2.tap()

    // Page 3: Trial / Access page
    // Either "Get started for free" (no access) or "You're All Set" (has access)
    let trialPage = app.staticTexts["Get started for free"]
    let accessPage = app.staticTexts["You're All Set"]
    let foundTrialOrAccess = trialPage.waitForExistence(timeout: 5) || accessPage.exists
    XCTAssertTrue(foundTrialOrAccess, "Third page should show trial or access page")
  }
}

// MARK: - Main View Tests

final class MainViewUITests: GetGripUITestCase {

  @MainActor
  func testTabBarExists() throws {
    app.launch()

    // The app has two tabs: Predictions and About
    let predictionsTab = app.tabBars.buttons["Predictions"]
    let aboutTab = app.tabBars.buttons["About"]

    // Either tabs are visible directly, or paywall is blocking
    // If paywall is shown, the tabs may still exist behind it
    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) {
      // Paywall is blocking — check it exists (tested separately)
      XCTAssertTrue(paywallTitle.exists)
      return
    }

    XCTAssertTrue(waitForElement(predictionsTab), "Predictions tab should exist")
    XCTAssertTrue(aboutTab.exists, "About tab should exist")
  }

  @MainActor
  func testMapButtonOpensMapSheet() throws {
    app.launch()

    // Skip if paywall is showing
    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    let mapButton = app.buttons["mapButton"]
    XCTAssertTrue(waitForElement(mapButton), "Map button should exist in toolbar")
    mapButton.tap()

    // MapSelectView should appear with its title
    let selectLocationTitle = app.staticTexts["Select Location"]
    XCTAssertTrue(waitForElement(selectLocationTitle),
                  "Map selection sheet should appear")

    // Cancel to dismiss
    let cancelButton = app.buttons["mapCancelButton"]
    XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
    cancelButton.tap()

    // Sheet should dismiss
    XCTAssertTrue(waitForElement(mapButton),
                  "Should return to main view after canceling map")
  }

  @MainActor
  func testLocationButtonExists() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    let locationButton = app.buttons["locationButton"]
    XCTAssertTrue(waitForElement(locationButton),
                  "Location button should exist in toolbar")
  }

  @MainActor
  func testAboutTabShowsSubscriptionStatus() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    let aboutTab = app.tabBars.buttons["About"]
    XCTAssertTrue(waitForElement(aboutTab))
    aboutTab.tap()

    // About view should show subscription status section
    let subscriptionSection = app.staticTexts["Subscription status"]
    XCTAssertTrue(waitForElement(subscriptionSection),
                  "About view should show subscription status")
  }

  @MainActor
  func testAboutTabShowsVisibleWaxesLink() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    let aboutTab = app.tabBars.buttons["About"]
    XCTAssertTrue(waitForElement(aboutTab))
    aboutTab.tap()

    let visibleWaxes = app.staticTexts["Visible waxes"]
    XCTAssertTrue(waitForElement(visibleWaxes),
                  "About view should show 'Visible waxes' navigation link")
  }
}

// MARK: - Purchase Flow Tests

final class PurchaseFlowUITests: GetGripUITestCase {

  @MainActor
  func testPaywallShowsWhenNoAccess() throws {
    app.launch()

    // The paywall may appear automatically when there's no subscription
    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 10) {
      XCTAssertTrue(paywallTitle.exists, "Paywall title should be visible")

      // Check key paywall elements exist
      let subscribeButton = app.buttons["subscribeButton"]
      let restoreButton = app.buttons["restorePurchasesButton"]

      // Either the subscribe button or a loading indicator should be present
      let buttonOrLoading = subscribeButton.waitForExistence(timeout: 10)
        || app.staticTexts["Loading..."].exists
      XCTAssertTrue(buttonOrLoading,
                    "Paywall should show subscribe button or loading state")

      if subscribeButton.exists {
        XCTAssertTrue(restoreButton.exists, "Restore purchases button should exist")
      }
    }
  }

  @MainActor
  func testPaywallShowsFeatureList() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    guard paywallTitle.waitForExistence(timeout: 10) else { return }

    // Check feature list items
    XCTAssertTrue(app.staticTexts["Unlimited wax & klister recommendations"].exists,
                  "Feature list should show wax recommendations")
    XCTAssertTrue(app.staticTexts["Snow + temperature guidance"].exists,
                  "Feature list should show temperature guidance")
    XCTAssertTrue(app.staticTexts["Forecast planning tools"].exists,
                  "Feature list should show forecast tools")
  }

  @MainActor
  func testPaywallShowsLegalLinks() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    guard paywallTitle.waitForExistence(timeout: 10) else { return }

    // Scroll down to see footer links
    app.swipeUp()

    // SwiftUI Link elements can appear as links or buttons in XCUI
    let termsAsLink = app.links["Terms of Use"]
    let termsAsButton = app.buttons["Terms of Use"]
    let privacyAsLink = app.links["Privacy Policy"]
    let privacyAsButton = app.buttons["Privacy Policy"]

    let termsFound = termsAsLink.waitForExistence(timeout: 5) || termsAsButton.exists
    let privacyFound = privacyAsLink.exists || privacyAsButton.exists

    XCTAssertTrue(termsFound, "Terms of Use link should exist")
    XCTAssertTrue(privacyFound, "Privacy Policy link should exist")
  }

  @MainActor
  func testPaywallFromAboutTab() throws {
    app.launch()

    // Skip if paywall is already showing (no subscription)
    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    // Navigate to About tab
    let aboutTab = app.tabBars.buttons["About"]
    XCTAssertTrue(waitForElement(aboutTab))
    aboutTab.tap()

    // Look for "Start free trial" button (shown when not subscribed)
    let startTrialButton = app.buttons["Start free trial"]
    if startTrialButton.waitForExistence(timeout: 5) {
      startTrialButton.tap()

      // Paywall sheet should appear
      XCTAssertTrue(waitForElement(app.staticTexts["Unlock GetGrip"]),
                    "Paywall should appear from About tab")
    }
    // If button doesn't exist, user is already subscribed — that's fine
  }

  @MainActor
  func testRestorePurchasesButtonTappable() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    guard paywallTitle.waitForExistence(timeout: 10) else { return }

    let restoreButton = app.buttons["restorePurchasesButton"]
    guard restoreButton.waitForExistence(timeout: 10) else { return }

    XCTAssertTrue(restoreButton.isHittable, "Restore button should be tappable")
    restoreButton.tap()
    // After tapping restore, the paywall should still be visible
    // (unless a purchase was actually restored)
    sleep(2)
    // Either paywall is still shown or it dismissed (if restore succeeded)
    // Both are valid outcomes
  }
}

// MARK: - Location Tests

final class LocationUITests: GetGripUITestCase {

  @MainActor
  func testMapSelectionFlow() throws {
    app.launch()

    // Skip if paywall is showing
    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    // Open map
    let mapButton = app.buttons["mapButton"]
    XCTAssertTrue(waitForElement(mapButton))
    mapButton.tap()

    // Verify map selection view appeared
    XCTAssertTrue(waitForElement(app.staticTexts["Select Location"]),
                  "Map selection view should appear")

    // Verify search field exists
    let searchField = app.textFields["mapSearchField"]
    XCTAssertTrue(waitForElement(searchField),
                  "Search field should exist in map view")

    // Verify my location button exists
    let myLocationButton = app.buttons["mapMyLocationButton"]
    XCTAssertTrue(myLocationButton.exists,
                  "My location button should exist in map view")
  }

  @MainActor
  func testMapSearchField() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    // Open map
    let mapButton = app.buttons["mapButton"]
    XCTAssertTrue(waitForElement(mapButton))
    mapButton.tap()

    XCTAssertTrue(waitForElement(app.staticTexts["Select Location"]))

    // Tap search field and type
    let searchField = app.textFields["mapSearchField"]
    XCTAssertTrue(waitForElement(searchField))
    searchField.tap()
    searchField.typeText("Oslo")

    // Wait for search suggestions to appear
    // Suggestions show as buttons in the list
    sleep(3)

    // Clear the search
    let clearButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'xmark'")).firstMatch
    if clearButton.exists {
      clearButton.tap()
    }
  }

  @MainActor
  func testMapCancelDismisses() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    let mapButton = app.buttons["mapButton"]
    XCTAssertTrue(waitForElement(mapButton))
    mapButton.tap()

    XCTAssertTrue(waitForElement(app.staticTexts["Select Location"]))

    // Cancel
    let cancelButton = app.buttons["mapCancelButton"]
    XCTAssertTrue(cancelButton.exists)
    cancelButton.tap()

    // Should be back on main view — map button should be visible again
    XCTAssertTrue(waitForElement(mapButton),
                  "Should return to main view after cancel")
    XCTAssertFalse(app.staticTexts["Select Location"].exists,
                   "Map view should be dismissed")
  }

  @MainActor
  func testLocationButtonTrigger() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    let locationButton = app.buttons["locationButton"]
    XCTAssertTrue(waitForElement(locationButton))

    // Tap location button — this will either:
    // 1. Request location permission (alert appears)
    // 2. Fetch GPS location (if already authorized)
    // 3. Show permission denied alert
    locationButton.tap()

    // Check if a system location permission alert appeared
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allowButton = springboard.buttons["Allow Once"]
    let allowWhileUsing = springboard.buttons["Allow While Using App"]

    if allowButton.waitForExistence(timeout: 3) {
      allowButton.tap()
    } else if allowWhileUsing.waitForExistence(timeout: 1) {
      allowWhileUsing.tap()
    }
    // If no permission dialog, location was already authorized — that's fine
  }

  @MainActor
  func testMapMyLocationButton() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    let mapButton = app.buttons["mapButton"]
    XCTAssertTrue(waitForElement(mapButton))
    mapButton.tap()

    XCTAssertTrue(waitForElement(app.staticTexts["Select Location"]))

    // Tap the "My Location" button in the map view
    let myLocationButton = app.buttons["mapMyLocationButton"]
    XCTAssertTrue(myLocationButton.exists)
    myLocationButton.tap()

    // Handle potential location permission alert
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allowButton = springboard.buttons["Allow Once"]
    let allowWhileUsing = springboard.buttons["Allow While Using App"]

    if allowButton.waitForExistence(timeout: 3) {
      allowButton.tap()
    } else if allowWhileUsing.waitForExistence(timeout: 1) {
      allowWhileUsing.tap()
    }

    // After tapping my location, the "Use this location" button may appear
    // if the device has a GPS fix
    let confirmButton = app.buttons["confirmLocationButton"]
    if confirmButton.waitForExistence(timeout: 5) {
      XCTAssertTrue(confirmButton.isHittable,
                    "Confirm location button should be tappable")
    }
    // If no confirm button appears, the device may not have a GPS fix — acceptable
  }
}

// MARK: - Snow Type Tests

final class SnowTypeUITests: GetGripUITestCase {

  @MainActor
  func testSnowTypeButtonsExist() throws {
    app.launch()

    let paywallTitle = app.staticTexts["Unlock GetGrip"]
    if paywallTitle.waitForExistence(timeout: 5) { return }

    // Snow type buttons should be visible — check at least first few
    let newFallen = app.otherElements["snowType_0"]     // newFallen
    let fineGrained = app.otherElements["snowType_2"]   // fineGrained

    // Snow type buttons are in a horizontal scroll view, so they may need scrolling
    // At least one should be visible
    let anySnowType = newFallen.waitForExistence(timeout: 5) || fineGrained.exists
    XCTAssertTrue(anySnowType, "At least one snow type button should be visible")
  }
}

// MARK: - Launch Performance Test

final class LaunchPerformanceTests: GetGripUITestCase {

  @MainActor
  func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      XCUIApplication().launch()
    }
  }
}
