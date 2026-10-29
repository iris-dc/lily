import XCTest

/// How the tests reach the screens behind the tabs (the inbox, a room, a card on Home or Explore) and the sign-in sheet
/// with its email form. The base file holds the launch and the gesture primitives; the helpers here are built on them
/// and shared by every test class.
extension LilyUITestCase {
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

    /// Opens `element` from Home. Home's games and tournaments are lazy rows under the groups section, so a card can
    /// sit outside the accessibility tree until a scroll instantiates it; the swipes come after the tab tap because a
    /// scrolled list minimises the tab bar.
    @MainActor
    func openFromHome(_ element: XCUIElement) {
        openHomeTab()
        _ = element.waitForExistence(timeout: 10)
        scrollUntilHittable(element)
        element.tap()
    }

    /// Opens the card titled `title` from Home. `@nonobjc`: the two overloads would otherwise share the Objective-C
    /// selector `openFromHome:`, and a helper needs no selector.
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

    /// The form's password field. It is a secure field only once it has been tapped; a row that looks like it holds its
    /// place before that, so the row is tapped first and the field it brings is returned.
    @MainActor
    func passwordField() -> XCUIElement {
        let field = app.secureTextFields["auth-password"]
        if !field.exists {
            let row = app.buttons["auth-password"]
            XCTAssertTrue(row.waitForExistence(timeout: 5), "the password row must be on the form")
            row.tap()
            XCTAssertTrue(field.waitForExistence(timeout: 5), "tapping the row must bring the secure field")
        }
        return field
    }
}
