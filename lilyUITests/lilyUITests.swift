import XCTest

/// End-to-end smoke tests against the real app in the simulator: landing, Explore, map, filters, joining, creating.
/// Sign-in flows are in `LilySignInTests`; both share `LilyUITestCase`.
final class LilySmokeTests: LilyUITestCase {
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

    /// The mock's "Doubles, all levels" starts at 1 of 4 and unjoined; a join must show on the detail at once and
    /// in Home on the way there, without a manual refresh. Leaving it from Home must turn the control back
    /// into Join and drop the game from that list on the way back, again without a reload. Nothing scrolls here on
    /// purpose: a scrolled list minimises the tab bar, and a minimised tab bar swallows tab taps.
    @MainActor
    func testJoiningFromTheDetailShowsOnHome() {
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
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), "the joined game must be listed under Home")

        app.staticTexts[title].tap()
        let leave = app.buttons["Leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5))
        leave.tap()

        XCTAssertTrue(join.waitForExistence(timeout: 5), "a leave must turn the control back into Join")
        XCTAssertTrue(app.staticTexts["1 of 4 joined"].exists, "the capacity must show the server's count")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        // The list animates the removal, so give it room.
        XCTAssertTrue(app.staticTexts[title].waitForNonExistence(timeout: 10), "a left game must drop out of Home")
    }

    /// The one tennis game in the fixtures costs money, so tennis plus "Free only" matches nothing: the map must stay
    /// on screen (on the user's position) instead of giving way to the "Nothing matches" state the list shows.
    @MainActor
    func testMapStaysWhenTheFilterHidesEveryGame() {
        relaunchAsGuest()
        showMap()

        app.buttons["events-filter"].tap()
        let tennis = app.buttons["filter-type-tennis"]
        XCTAssertTrue(tennis.waitForExistence(timeout: 5), "the filter panel should drop down")
        tennis.tap()
        app.buttons["filter-free-only"].tap()
        app.buttons["Done"].tap()

        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 5), "the map stays whatever the criteria match")
        XCTAssertTrue(app.descendants(matching: .any)["Doubles, all levels"].firstMatch.waitForNonExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Nothing matches"].exists, "the list's empty state must not replace the map")
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

    @MainActor
    func testGuestPlusGroupItemOpensSignIn() {
        relaunchAsGuest()

        tapCreateMenuItem("New group")

        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 5), "a guest must be asked to sign in first")
        XCTAssertFalse(app.navigationBars["New group"].exists, "the form must not open for a guest")
    }

    /// The mock location fills the spot, so title and place are all the form still needs. The new game must show
    /// under Home without a manual refresh, and its detail must know the caller hosts it. Nothing scrolls before
    /// the tab tap: a scrolled list minimises the tab bar, and a minimised tab bar swallows tab taps.
    @MainActor
    func testCreatingAGameShowsItOnHome() {
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

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        let card = app.staticTexts[title]
        if !card.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the hosted game must be listed under Home")

        card.tap()
        XCTAssertTrue(app.staticTexts["You host this game"].waitForExistence(timeout: 5), "the host must see the hosting notice")
    }
}
