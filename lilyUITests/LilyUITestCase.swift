import XCTest

/// Shared launch and helpers of the UI test classes. The app starts on the landing with the session reset, mock
/// location, mock auth and mock events (mirroring `AppConfig.LaunchArguments`; the test target cannot import the app
/// module), so no run depends on the Cognito pool or a running backend. The app is pinned to English, which keeps the
/// copy assertions independent of the Mac's language list, which the simulator inherits (`AppleLanguages`); the region
/// stays the simulator's, so distances and currency symbols follow it. The aurora is frozen on its first frame: its
/// 30 fps redraw kept the simulator's compositor at two fifths of a core on a Mac and starved the GitHub runner, which
/// renders in software, into launch and snapshot timeouts.
class LilyUITestCase: XCTestCase {
    let app = XCUIApplication()

    /// What every launch passes; a relaunch that replaces the arguments starts from here.
    static let launchArguments = ["-reset-session", "-mock-location", "-mock-auth", "-mock-events", "-freeze-aurora",
                                  "-app-language", "en"]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = Self.launchArguments
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

    /// Tab titles double as the roots' navigation titles, so one name finds both.
    @MainActor
    private func openTab(titled title: String) {
        selectTab(title)
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    /// Selects a tab and asserts nothing about the screen it shows: for a tab whose stack is not at its root (the
    /// Chats stack under the inbox, which hides the tab bar), where the root's title is not what appears. The iPhone's
    /// bar is a `tabBar`; the iPad's top bar exposes each tab as a plain button nested in another with the same label
    /// and no `tabBar` around them, so the fallback takes the first button with that exact label.
    @MainActor
    func selectTab(_ title: String) {
        let inBar = app.tabBars.buttons[title]
        var isInBar = inBar.waitForExistence(timeout: 3)
        if !isInBar, expandMinimisedTabBar() {
            isInBar = inBar.waitForExistence(timeout: 3)
        }
        let tab = isInBar ? inBar : app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
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
    @MainActor
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

    /// Pulls the content down, slowly, from the upper half of the screen so a `.refreshable` fires: a quick
    /// `swipeDown()` may not pass its threshold, and the pull ends above the tab bar.
    @MainActor
    func pullToRefresh() {
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            .press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.3)
    }

    /// The way a scroll-until loop moves the content: `up` reaches content further down, `down` content above.
    enum ScrollDirection {
        case up
        case down
    }

    /// Swipes in `direction` until `element` is in the accessibility tree and hittable, at most `maxSwipes` times, and
    /// fails when it never is. Kept as an explicit `while`: a `for … where` guard does not reliably run its check or
    /// its swipe here.
    @MainActor
    func scrollUntilHittable(_ element: XCUIElement, direction: ScrollDirection = .up, maxSwipes: Int = 8) {
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < maxSwipes {
            switch direction {
            case .up: app.swipeUp()
            case .down: app.swipeDown()
            }
            swipes += 1
        }
        XCTAssertTrue(element.exists && element.isHittable, "element never scrolled into a hittable position")
    }

    /// Waits for `element` to become enabled: a CI runner can be two to three times slower than a developer Mac, so an
    /// `isEnabled` read right after typing or a tap must wait.
    @MainActor
    func assertBecomesEnabled(_ element: XCUIElement, _ message: String = "", timeout: TimeInterval = 5) {
        XCTAssertTrue(element.wait(for: \.isEnabled, toEqual: true, timeout: timeout), message)
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

    /// Focuses a text field and types into it. A field that already has keyboard focus is not tapped first:
    /// `XCUIElement.tap()` resolves its target through the accessibility tree, and with the keyboard up over a scrolled
    /// transcript a row under the glass composer wins the hit and pushes its event. A coordinate touch is no answer
    /// either: a form field under the keyboard needs `tap()`, which brings it into view. A field not yet in the tree is
    /// dragged into it first (`dragUpUntilExists`): a `Form` row below the fold is not in the accessibility tree at all,
    /// and a row that shows on one phone model can be below the fold on another.
    @MainActor
    func enter(_ text: String, into field: XCUIElement) {
        if !field.waitForExistence(timeout: 5) { dragUpUntilExists(field) }
        if !field.hasKeyboardFocus {
            field.tap()
            // On the runner the focus arrives after the tap has returned, and a `typeText` before it fails with "Neither
            // element nor any descendant has keyboard focus"; a tap that scrolled the row instead of focusing it is
            // repeated once.
            if !waitForKeyboardFocus(field) {
                field.tap()
                XCTAssertTrue(waitForKeyboardFocus(field), "the field must take the keyboard focus before typing")
            }
        }
        field.typeText(text)
    }

    /// Whether `field` takes the keyboard focus within `timeout`; the focus is a private attribute, so it is polled.
    @MainActor
    @discardableResult
    func waitForKeyboardFocus(_ field: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let focused = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: field)
        return XCTWaiter().wait(for: [focused], timeout: timeout) == .completed
    }

    /// Long-presses `row` until its context menu offers `item`, up to three times: the runner turned one press into a
    /// scroll, and waited longer for the menu than a Mac does (a second press while the menu was still opening found no
    /// row under it, so each press is given a long wait before the next).
    @MainActor
    func openContextMenu(on row: XCUIElement, until item: XCUIElement) {
        scrollUntilHittable(row)
        var presses = 0
        while !item.exists && presses < 3 {
            row.press(forDuration: 1.2)
            _ = item.waitForExistence(timeout: 8)
            presses += 1
        }
        XCTAssertTrue(item.exists, "the row's menu must offer the action")
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

    /// Opens the sign-in sheet from the landing and pushes the email form.
    @MainActor
    func openEmailForm() {
        openSignInSheet()
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
