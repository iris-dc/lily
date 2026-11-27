import XCTest

/// The segmented Home's identifiers, mirrored by hand from `AccessibilityIdentifiers+Home.swift` like `MockIDs`
/// (the test target cannot import the app): a rename there must be mirrored here.
enum HomeIDs {
    static let segment = "home-segment"
    static let create = "home-create"
}

/// How the tests reach the screens behind the tabs (the inbox, a room, a card on Home or Explore) and the sign-in sheet
/// with its email form. The base file holds the launch and the gesture primitives; the helpers here are built on them
/// and shared by every test class.
extension LilyUITestCase {
    /// Selects a tab by its ⌘ shortcut (mirroring `ShellCommands`: ⌘1 Home, ⌘2 Explore, ⌘3 Chats) from a screen that
    /// hides the tab bar — a detail or a room — until `arrival` shows. A keystroke typed while a push or pop is still
    /// settling is dropped, so it is repeated, bounded, as the context-menu primitive repeats its press.
    @MainActor
    func selectTabByShortcut(_ number: Int, until arrival: XCUIElement) {
        var attempts = 0
        repeat {
            app.typeKey(String(number), modifierFlags: .command)
            attempts += 1
        } while !arrival.waitForExistence(timeout: 3) && attempts < 3
        XCTAssertTrue(arrival.exists, "⌘\(number) must select its tab")
    }

    /// Opens the Chats tab and pushes the inbox from its pinned row; the inbox is titled with the app's name.
    @MainActor
    func openInbox() {
        openChatsTab()
        let row = app.buttons["inbox-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["iskra"].waitForExistence(timeout: 10))
    }

    /// Opens the Chats tab and answers the row `rowID`, for a check on the row before it is tapped (an unread dot, a
    /// caption).
    @MainActor
    @discardableResult
    func chatsRow(_ rowID: String) -> XCUIElement {
        openChatsTab()
        let row = app.buttons[rowID]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Chats lists \(rowID)")
        return row
    }

    /// Opens the room behind the Chats row `rowID` and waits for its title.
    @MainActor
    func openRoom(_ rowID: String, titled title: String) {
        chatsRow(rowID).tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), "the row opens the room")
    }

    /// Picks the segment `title` (Events | Tournaments | Groups) of Home's picker, scrolling back up to it when the
    /// segment's content pushed it off screen: the picker scrolls with the content, like the detail pickers.
    @MainActor
    func selectHomeSegment(_ title: String) {
        let picker = app.segmentedControls[HomeIDs.segment]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "Home shows its segment picker")
        scrollUntilHittable(picker, direction: .down, maxSwipes: 4)
        picker.buttons[title].tap()
    }

    /// Opens `element` from Home, picking `segment` first where the element lives off the default Events segment:
    /// Home shows one segment's list at a time. A card below the fold is not in the accessibility tree until a
    /// scroll instantiates it, and the swipes come after the tab tap because a scrolled list minimises the tab bar.
    @MainActor
    func openFromHome(_ element: XCUIElement, segment: String? = nil) {
        openHomeTab()
        if let segment { selectHomeSegment(segment) }
        tapAfterScrolling(element)
    }

    /// Opens the event card titled `title` from Home's default Events segment. `@nonobjc`: a helper needs no
    /// Objective-C selector, and the overloads must not share one.
    @MainActor
    @nonobjc
    func openFromHome(_ title: String) {
        openFromHome(app.staticTexts[title])
    }

    /// An event card on Explore or Home by words of its label; a second term, the place, tells the card from the map
    /// pin of the same title.
    @MainActor
    func card(containing terms: String...) -> XCUIElement {
        let predicates = terms.map { NSPredicate(format: "label CONTAINS %@", $0) }
        return app.buttons.matching(NSCompoundPredicate(andPredicateWithSubpredicates: predicates)).firstMatch
    }

    /// Pushes Discover from the carousel's "See all" on Explore; the carousel shows once Discover has answered.
    @MainActor
    func showDiscover() {
        let seeAll = app.buttons["groups-see-all"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10))
        seeAll.tap()
        XCTAssertTrue(app.navigationBars["Discover groups"].waitForExistence(timeout: 5))
    }

    /// Opens the profile sheet from the corner button on the current tab root and waits for its title: "Profile" is
    /// the sheet's navigation title, no tab's.
    @MainActor
    func openProfileSheet() {
        let corner = app.buttons["profile-corner"]
        XCTAssertTrue(corner.waitForExistence(timeout: 10), "the tab root carries the corner profile button")
        corner.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
    }

    /// Closes the profile sheet by dragging it down from its bar, and waits for the root's corner button to be back.
    @MainActor
    func closeProfileSheet() {
        let grabber = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        grabber.press(forDuration: 0.1, thenDragTo: bottom, withVelocity: .default, thenHoldForDuration: 0)
        let corner = app.buttons["profile-corner"]
        XCTAssertTrue(corner.waitForExistence(timeout: 5), "the root is back once the sheet is gone")
        waitUntilHittableAndStill(corner)
    }

    /// Pushes Settings from the signed-in profile root's link row and waits for its title.
    @MainActor
    func openSettings() {
        let row = app.buttons["profile-settings"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the signed-in profile root offers Settings")
        row.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    /// Opens the sign-in sheet from whatever screen shows "Sign in": the landing, Home's guest prompt or Profile.
    @MainActor
    func openSignInSheet() {
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()
    }

    /// Opens the sign-in sheet from whatever screen shows "Sign in" and picks the mock Apple provider. Returns the
    /// provider button, so callers can watch the sheet close or stay.
    @MainActor
    @discardableResult
    func tapSignInWithApple() -> XCUIElement {
        openSignInSheet()
        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        apple.tap()
        return apple
    }

    /// Opens the sign-in sheet from the landing and pushes the email form, and returns once the form has stopped
    /// sliding in: the field exists while the push is still running, which the idle wait does not cover, and a tap
    /// landing on a moving row left the button pressed and the tap lost.
    @MainActor
    func openEmailForm() {
        openSignInSheet()
        let email = app.buttons["Continue with Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        let field = app.textFields["auth-email"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        waitUntilHittableAndStill(field)
    }
}
