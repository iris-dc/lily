import XCTest

/// End-to-end smoke tests against the real app in the simulator.
final class LilySmokeTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Mirrors AppConfig.LaunchArguments (UI tests cannot import the app module). `-mock-events` keeps these
        // runs independent of a running backend.
        app.launchArguments = ["-reset-session", "-mock-location", "-mock-events"]
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
        tapSignInWithApple()

        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSignInFailureShowsThePopupAboveTheSheet() {
        app.terminate()
        app.launchArguments.append("-mock-auth-fail")
        app.launch()
        let apple = tapSignInWithApple()

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
        let apple = tapSignInWithApple()

        XCTAssertTrue(apple.waitForNonExistence(timeout: 10), "the sheet must close once the guest is signed in")
        XCTAssertTrue(app.staticTexts["Apple Tester"].waitForExistence(timeout: 5))
    }

    /// The mock's "Doubles, all levels" starts at 1 of 4 and unjoined; a join must show on the detail at once and
    /// in My Events on the way there, without a manual refresh. Leaving it from My Events must turn the control back
    /// into Join and drop the game from that list on the way back, again without a reload. Nothing scrolls here on
    /// purpose: a scrolled list minimises the tab bar, and a minimised tab bar swallows tab taps.
    @MainActor
    func testJoiningFromTheDetailShowsInMyEvents() {
        tapSignInWithApple()
        let title = "Doubles, all levels"
        let card = app.staticTexts[title]
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()

        let join = app.buttons["Join"]
        XCTAssertTrue(join.waitForExistence(timeout: 5))
        join.tap()

        XCTAssertTrue(app.buttons["Leave"].waitForExistence(timeout: 5), "a join must turn the control into Leave")
        XCTAssertTrue(app.staticTexts["2 of 4 joined"].exists, "the capacity must show the server's count")

        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["My Events"].tap()
        XCTAssertTrue(app.navigationBars["My Events"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), "the joined game must be listed under My Events")

        app.staticTexts[title].tap()
        let leave = app.buttons["Leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        leave.tap()

        XCTAssertTrue(join.waitForExistence(timeout: 5), "a leave must turn the control back into Join")
        XCTAssertTrue(app.staticTexts["1 of 4 joined"].exists, "the capacity must show the server's count")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["My Events"].waitForExistence(timeout: 5))
        // The list animates the removal, so give it room.
        XCTAssertTrue(app.staticTexts[title].waitForNonExistence(timeout: 10), "a left game must drop out of My Events")
    }

    @MainActor
    func testFilterPanelNarrowsListAndMap() {
        relaunchAsGuest()
        XCTAssertTrue(app.staticTexts["Pickup at the Cage"].waitForExistence(timeout: 5))

        app.buttons["events-filter"].tap()
        let football = app.buttons["filter-type-football"]
        XCTAssertTrue(football.waitForExistence(timeout: 5), "the filter panel should drop down")
        football.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Pickup at the Cage"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sunset 5-a-side"].exists)

        showMap()
        // Annotations are not descendants of the map element, so query the whole app.
        XCTAssertTrue(app.descendants(matching: .any)["Sunset 5-a-side"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["Pickup at the Cage"].firstMatch.exists)

        app.buttons["events-filter"].tap()
        let reset = app.buttons["Reset"]
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["Pickup at the Cage"].firstMatch.waitForExistence(timeout: 10))
    }

    /// Creating needs an account: a guest's "+" opens the sign-in sheet, not the form.
    @MainActor
    func testGuestPlusOpensSignIn() {
        relaunchAsGuest()

        tapCreateButton()

        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 5), "a guest must be asked to sign in first")
        XCTAssertFalse(app.navigationBars["New game"].exists, "the form must not open for a guest")
    }

    /// The mock location fills the spot, so title and place are all the form still needs. The new game must show
    /// under My Events without a manual refresh, and its detail must know the caller hosts it. Nothing scrolls before
    /// the tab tap: a scrolled list minimises the tab bar, and a minimised tab bar swallows tab taps.
    @MainActor
    func testCreatingAGameShowsItInMyEvents() {
        tapSignInWithApple()
        tapCreateButton()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 5))

        let title = "Thursday five-a-side"
        enter(title, into: app.textFields["create-title"])
        enter("Test Park", into: app.textFields["create-location-name"])

        let submit = app.buttons["create-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isEnabled, "title, place and the mock position complete the draft")
        submit.tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForNonExistence(timeout: 10), "the sheet must close once created")

        app.tabBars.buttons["My Events"].tap()
        XCTAssertTrue(app.navigationBars["My Events"].waitForExistence(timeout: 5))
        let card = app.staticTexts[title]
        if !card.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the hosted game must be listed under My Events")

        card.tap()
        XCTAssertTrue(app.staticTexts["You host this game"].waitForExistence(timeout: 5), "the host must see the hosting notice")
    }

    // MARK: - Helpers

    /// Taps the floating "+" on Explore (AccessibilityIdentifiers.eventsCreate); waits out the sign-in transition too.
    @MainActor
    private func tapCreateButton() {
        let create = app.buttons["events-create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()
    }

    /// Focuses a text field and types into it.
    @MainActor
    private func enter(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "missing text field")
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func relaunchAsGuest() {
        app.terminate()
        app.launchArguments.append("-start-as-guest")
        app.launch()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
    }

    /// Opens the sign-in sheet from whatever screen shows "Sign in" and picks the mock Apple provider. Returns the
    /// provider button, so callers can watch the sheet close or stay.
    @MainActor
    @discardableResult
    private func tapSignInWithApple() -> XCUIElement {
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        apple.tap()
        return apple
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
