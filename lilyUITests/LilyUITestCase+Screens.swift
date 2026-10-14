import XCTest

/// How the tests reach the screens behind the tabs: the inbox, a room, a card on Home or Explore. The base file holds
/// the launch and the gesture primitives; the helpers here are built on them and shared by every test class.
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

    /// Opens the card titled `title` from Home. `@nonobjc` because the two overloads would otherwise share the
    /// Objective-C selector `openFromHome:` (the `relaunch(appending:)` clash again); helpers need no selector.
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
}
