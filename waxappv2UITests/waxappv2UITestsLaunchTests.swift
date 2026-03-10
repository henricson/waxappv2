import XCTest

final class GetGripLaunchTests: XCTestCase {

  override class var runsForEachTargetApplicationUIConfiguration: Bool {
    false
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testLaunchScreenshot() throws {
    let app = XCUIApplication()
    app.launchArguments += ["-hasSeenOnboarding", "YES"]
    app.launch()

    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Launch Screen"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testOnboardingScreenshot() throws {
    let app = XCUIApplication()
    app.launchArguments += ["-hasSeenOnboarding", "NO"]
    app.launch()

    // Wait for onboarding to appear
    let welcome = app.staticTexts["Welcome to GetGrip"]
    if welcome.waitForExistence(timeout: 5) {
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = "Onboarding Screen"
      attachment.lifetime = .keepAlways
      add(attachment)
    }
  }
}
