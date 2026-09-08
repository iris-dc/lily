import XCTest

/// End-to-end smoke tests against the real app in the simulator.
final class LilySmokeTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Mirrors AppConfig.LaunchArguments (UI tests cannot import the app module).
        app.launchArguments = ["-reset-session", "-mock-location"]
        app.launch()
    }

    @MainActor
    func testLandingExplainsProductAndOffersEntry() {
        XCTAssertTrue(app.staticTexts["lily"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Play tonight."].exists)
        XCTAssertTrue(app.buttons["Find a game near you"].exists)
        XCTAssertTrue(app.buttons["Sign in"].exists)
    }

    @MainActor
    func testPrimaryActionReachesExploreFeed() {
        let enter = app.buttons["Find a game near you"]
        XCTAssertTrue(enter.waitForExistence(timeout: 5))
        enter.tap()

        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sunset 5-a-side"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testExploreCanSwitchToMap() {
        app.terminate()
        app.launchArguments.append("-start-as-guest")
        app.launch()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))

        // Segments expose their SF Symbol name as identifier (DesignTokens.Symbols.map).
        app.segmentedControls["events-presentation"].buttons["map"].tap()
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10))
        sleep(2)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "explore-map"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testMockAppleSignInFromSheetLandsInApp() {
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        apple.tap()

        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
    }
}
