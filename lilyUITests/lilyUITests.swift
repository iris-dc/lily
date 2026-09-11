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
        XCTAssertTrue(app.staticTexts["Play tonight."].waitForExistence(timeout: 5))
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
        relaunchAsGuest()
        showMap()
        attachScreenshot(named: "explore-map")
    }

    @MainActor
    func testMapSelectedCardStaysAboveTheTabBar() {
        relaunchAsGuest()
        showMap()

        // Annotations are not descendants of the map element, so query the whole app.
        let pin = app.descendants(matching: .any)["Sunset 5-a-side"].firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 10))
        waitUntilHittableAndStill(pin)
        pin.tap()

        let card = app.buttons["map-selected-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists, "expected a tab bar to measure the card against")
        XCTAssertLessThanOrEqual(
            card.frame.maxY,
            tabBar.frame.minY,
            "the selected-event card must not run under the tab bar"
        )
        attachScreenshot(named: "map-selected-card")
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

    @MainActor
    func testSignInFailureShowsThePopupAboveTheSheet() {
        app.terminate()
        app.launchArguments.append("-mock-auth-fail")
        app.launch()
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        apple.tap()

        // The popup combines its children into one element, so match on the label.
        let popup = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "You're offline")).firstMatch
        XCTAssertTrue(popup.waitForExistence(timeout: 10), "a failed sign-in must show the shared error popup")
        waitUntilHittableAndStill(popup)
        XCTAssertTrue(popup.isHittable, "the popup must sit above the sheet, not behind it")
        XCTAssertTrue(apple.exists, "the sheet stays open after a failed sign-in")
    }

    @MainActor
    func testSignInFromProfileDismissesTheSheet() {
        relaunchAsGuest()
        app.tabBars.buttons["Profile"].tap()
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        apple.tap()

        XCTAssertTrue(apple.waitForNonExistence(timeout: 10), "the sheet must close once the guest is signed in")
        XCTAssertTrue(app.staticTexts["Apple Tester"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    @MainActor
    private func relaunchAsGuest() {
        app.terminate()
        app.launchArguments.append("-start-as-guest")
        app.launch()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func showMap() {
        // Segments expose their SF Symbol name as identifier (DesignTokens.Symbols.map).
        app.segmentedControls["events-presentation"].buttons["map"].tap()
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10))
    }

    /// The map camera animates to frame every pin; tapping before it settles hits a stale frame.
    @MainActor
    private func waitUntilHittableAndStill(_ element: XCUIElement, timeout: TimeInterval = 10) {
        var previous = element.frame
        for _ in 0..<Int(timeout * 4) {
            usleep(250_000)
            let current = element.frame
            if current == previous && element.isHittable { return }
            previous = current
        }
        XCTFail("element never settled into a hittable position")
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
