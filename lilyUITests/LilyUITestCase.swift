import XCTest

/// Shared launch and helpers of the UI test classes. The app starts on the landing with the session reset, mock
/// location, mock auth and mock events (mirroring `AppConfig.LaunchArguments`; the test target cannot import the app
/// module), so no run depends on the Cognito pool or a running backend.
class LilyUITestCase: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-reset-session", "-mock-location", "-mock-auth", "-mock-events"]
        app.launch()
    }

    /// Relaunches with one more argument, for a launch that needs another mock behaviour.
    @MainActor
    func relaunch(appending argument: String) {
        relaunch(appendingArguments: [argument])
    }

    /// Relaunches with more arguments, for a flag that takes a value (`-mock-user-id <sub>`).
    @MainActor
    func relaunch(appendingArguments arguments: [String]) {
        app.terminate()
        app.launchArguments += arguments
        app.launch()
    }

    /// Opens the Home tab and waits for its root.
    @MainActor
    func openHomeTab() {
        openTab(titled: "Home")
    }

    /// Opens the Chats tab (the inbox row and the caller's rooms) and waits for its root.
    @MainActor
    func openChatsTab() {
        openTab(titled: "Chats")
    }

    @MainActor
    func openExploreTab() {
        openTab(titled: "Explore")
    }

    /// Opens the Profile tab (the account, the language row and the contact row) and waits for its root.
    @MainActor
    func openProfileTab() {
        openTab(titled: "Profile")
    }

    /// Tab titles double as the roots' navigation titles, so one name finds both. The iPhone's bar is a `tabBar`;
    /// the iPad's top bar exposes each tab as a plain button nested in another with the same label and no `tabBar`
    /// around them, so the fallback takes the first button with that exact label.
    @MainActor
    private func openTab(titled title: String) {
        let inBar = app.tabBars.buttons[title]
        var isInBar = inBar.waitForExistence(timeout: 3)
        if !isInBar, expandMinimisedTabBar() {
            isInBar = inBar.waitForExistence(timeout: 3)
        }
        let tab = isInBar ? inBar : app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    /// A screen scrolled down has minimised the tab bar (iOS 26 `tabBarMinimizeBehavior`): the bar keeps only the
    /// selected tab, a pill whose value reads "Collapsed", and the other tabs' buttons leave the hierarchy. A scroll
    /// back up restores the bar only while the content is taller than the screen (a detail that shrank after a write
    /// fits a tall simulator and stays put), so the pill is tapped instead, which expands the bar either way. Asked
    /// only once the wanted tab was not found: right after a sign-in the appearing bar reports a pill for a moment
    /// and a tap on it misses. Answers whether a pill was there.
    @MainActor
    private func expandMinimisedTabBar() -> Bool {
        let pill = app.tabBars.buttons.matching(NSPredicate(format: "value == %@", "Collapsed")).firstMatch
        guard pill.exists else { return false }
        pill.tap()
        XCTAssertTrue(pill.waitForNonExistence(timeout: 5), "a tap on the minimised tab bar expands it")
        return true
    }

    /// The first element whose label contains `text`; for texts that a control folds into its own label.
    func labelled(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Drags the content up until `element` is in the accessibility tree, for a `Form` row below the fold while a field
    /// has the keyboard: an off-screen row is not in the tree at all, and `swipeUp()` starts 100 pt under the window's
    /// centre, which on a 6.1-inch phone is the keyboard's predictive bar, where a swipe scrolls nothing. The drag runs
    /// through the upper half instead, and a `Form` dismisses the keyboard on the scroll.
    @MainActor
    func dragUpUntilExists(_ element: XCUIElement, maxDrags: Int = 4) {
        var drags = 0
        while !element.waitForExistence(timeout: 1) && drags < maxDrags {
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15))
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
                .press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.1)
            drags += 1
        }
        XCTAssertTrue(element.exists, "element never scrolled into the accessibility tree")
    }

    /// Swipes up until `element` exists and is hittable, for content further down a list; fails after `maxSwipes`.

    func scrollUntilHittable(_ element: XCUIElement, maxSwipes: Int = 8) {
        for _ in 0..<maxSwipes where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable, "element never scrolled into a hittable position")
    }

    @MainActor
    func relaunchAsGuest() {
        relaunch(appending: "-start-as-guest")
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
    }

    /// Opens the floating "+" menu on Explore (AccessibilityIdentifiers.eventsCreate) and picks "New game".
    @MainActor
    func tapCreateButton() {
        tapCreateMenuItem("New game")
    }

    /// Opens the floating "+" menu on Explore and picks one of its items by title ("New game", "New group").
    @MainActor
    func tapCreateMenuItem(_ title: String) {
        let create = app.buttons["events-create"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "the create menu must offer \(title)")
        item.tap()
    }

    /// Focuses a text field and types into it. A field that already has keyboard focus is typed into as it is:
    /// `XCUIElement.tap()` resolves its target through the accessibility tree, and when the keyboard rose while the
    /// transcript was scrolled up (a reply to an early message) a row lay under the glass composer, won the hit and
    /// pushed its event, so the composer "vanished" (2026-10-08). A coordinate touch is no answer either: a form field
    /// under the keyboard needs `tap()`, which brings it into view.
    @MainActor
    func enter(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "missing text field")
        if !field.hasKeyboardFocus { field.tap() }
        field.typeText(text)
    }

    /// Opens the sign-in sheet from whatever screen shows "Sign in" and picks the mock Apple provider. Returns the
    /// provider button, so callers can watch the sheet close or stay.
    @MainActor
    @discardableResult
    func tapSignInWithApple() -> XCUIElement {
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()

        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        apple.tap()
        return apple
    }

    /// Opens the sign-in sheet from the landing and pushes the email form.
    @MainActor
    func openEmailForm() {
        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()
        let email = app.buttons["Continue with Email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        XCTAssertTrue(app.textFields["auth-email"].waitForExistence(timeout: 5))
    }

    @MainActor
    func showMap() {
        // Segments expose their SF Symbol name as identifier (DesignTokens.Symbols.map).
        app.segmentedControls["events-presentation"].buttons["map"].tap()
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10))
    }

    /// The map camera animates to frame every pin; tapping before it settles hits a stale frame.
    @MainActor
    func waitUntilHittableAndStill(_ element: XCUIElement, timeout: TimeInterval = 10) {
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
    func attachScreenshot(named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}

private extension XCUIElement {
    /// The "Keyboard Focused" attribute the hierarchy dump prints; not surfaced as a property on iOS.
    var hasKeyboardFocus: Bool { (value(forKey: "hasKeyboardFocus") as? Bool) ?? false }
}
