import XCTest

/// End-to-end smoke tests against the real app in the simulator: landing, Explore, map, filters, joining, creating.
/// Sign-in flows are in `LilySignInTests`; both share `LilyUITestCase`.
final class LilySmokeTests: LilyUITestCase {
    /// The landing is a vertical feed of four slides (the events to find, how to join one, the groups, the tournaments)
    /// with the two ways in under every one of them.
    @MainActor
    func testLandingIntroSwipesThroughTheSlidesAndKeepsTheWaysIn() {
        XCTAssertTrue(app.staticTexts["near you."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Explore events"].exists)
        XCTAssertTrue(app.buttons["Sign in"].exists)

        // Every slide is in the tree from the start (a plain VStack), so hittability is what tells the page on screen.
        let pager = app.scrollViews["intro-pager"]
        XCTAssertTrue(pager.exists)
        XCTAssertTrue(app.staticTexts["near you."].isHittable)
        XCTAssertFalse(app.staticTexts["in one tap."].isHittable)
        pager.swipeUp()
        XCTAssertTrue(app.staticTexts["in one tap."].wait(for: \.isHittable, toEqual: true, timeout: 5))
        XCTAssertFalse(app.staticTexts["near you."].isHittable)
        XCTAssertFalse(app.staticTexts["or start one."].isHittable, "one swipe must move one page")
        pager.swipeUp()
        XCTAssertTrue(app.staticTexts["or start one."].wait(for: \.isHittable, toEqual: true, timeout: 5))
        pager.swipeUp()
        XCTAssertTrue(app.staticTexts["or set one up."].wait(for: \.isHittable, toEqual: true, timeout: 5))
        XCTAssertFalse(app.staticTexts["or start one."].isHittable)
        XCTAssertTrue(app.buttons["Explore events"].isHittable)
        XCTAssertTrue(app.buttons["Sign in"].isHittable)
    }

    @MainActor
    func testPrimaryActionReachesExploreFeed() {
        let enter = app.buttons["Explore events"]
        XCTAssertTrue(enter.waitForExistence(timeout: 5))
        enter.tap()

        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Sunset 5-a-side"].waitForExistence(timeout: 5))
    }

    /// The profile is no tab: the corner button on Home opens it as a sheet.
    @MainActor
    func testCornerButtonOnHomeOpensTheProfileSheet() {
        tapSignInWithApple()
        openHomeTab()
        openProfileSheet()

        XCTAssertTrue(app.staticTexts["apple@example.com"].waitForExistence(timeout: 5), "the sheet shows the account")
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
        openFromHome(title)
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

    /// Creating needs an account: a guest's "+" goes straight to the sign-in sheet, never the wizard.
    @MainActor
    func testGuestPlusOpensSignIn() {
        relaunchAsGuest()

        tapCreateButton()

        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 5), "a guest must be asked to sign in first")
        XCTAssertFalse(app.navigationBars[Self.wizardKindTitle].exists, "the wizard must not open for a guest")
    }

    /// The guest's "+" offers no kind choice either: none of the kind page's cards shows, only sign-in.
    @MainActor
    func testGuestPlusShowsNoKindCards() {
        relaunchAsGuest()

        tapCreateButton()

        XCTAssertTrue(app.buttons["Continue with Apple"].waitForExistence(timeout: 5), "a guest must be asked to sign in first")
        XCTAssertFalse(app.buttons["create-kind-group"].exists, "no kind card shows for a guest")
        XCTAssertFalse(app.navigationBars[Self.wizardKindTitle].exists, "the kind page must not open for a guest")
    }

    /// The "+" opens the wizard on its kind page, whose Event card opens Name; the mock location fills the spot, so
    /// the title and the place name walk it to the end. On the way the pick-on-map row must push the picker, and back
    /// must keep the typed title (the plan's pinned wizard behaviours). The new game must show under Home without a
    /// manual refresh, and its detail must know the caller hosts it. Nothing scrolls before the tab tap: a scrolled
    /// list minimises the tab bar, and a minimised tab bar swallows tab taps.
    @MainActor
    func testCreatingAGameShowsItOnHome() {
        tapSignInWithApple()
        tapCreateButton()
        pickCreationKind("create-kind-event")

        let title = "Thursday five-a-side"
        waitForWizardStep("Name")
        enter(title, into: app.textFields["create-title"])
        walkWizardNameToPlace()
        openWizardMapAndReturn()
        assertBackToNameKeeps(title)
        walkWizardNameToPlace()
        enter("Test Park", into: app.textFields["create-location-name"])
        tapNext()
        waitForWizardStep("Players")
        continueToDetails()
        submitWizard()

        openFromHome(title)
        XCTAssertTrue(app.staticTexts["You host this event"].waitForExistence(timeout: 5), "the host must see the hosting notice")
    }

    /// The pick-on-map row pushes the picker on the wizard's own stack; Done returns to the Place step.
    @MainActor
    private func openWizardMapAndReturn() {
        let row = app.descendants(matching: .any)["create-pick-on-map"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.navigationBars["Where is it?"].waitForExistence(timeout: 5), "the map row must push the picker")
        app.buttons["create-map-done"].tap()
        waitForWizardStep("Place")
    }

    /// Back within the kind's steps is free and preserves entered state (the plan's pinned behaviour): Place pops
    /// through Hosting group, When and Type to Name, where the typed title still reads.
    @MainActor
    private func assertBackToNameKeeps(_ title: String) {
        tapWizardBack(from: "Place", to: "Hosting group")
        tapWizardBack(from: "Hosting group", to: "When")
        tapWizardBack(from: "When", to: "Type")
        tapWizardBack(from: "Type", to: "Name")
        XCTAssertEqual(app.textFields["create-title"].value as? String, title, "back must preserve the typed title")
    }
}
