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

    /// Tab titles double as the roots' navigation titles, so one name finds both.
    @MainActor
    private func openTab(titled title: String) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        tab.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    /// The first element whose label contains `text`; for texts that a control folds into its own label.

    func labelled(_ text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
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

    /// Focuses a text field and types into it.
    @MainActor
    func enter(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "missing text field")
        field.tap()
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
