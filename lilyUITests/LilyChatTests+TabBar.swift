import XCTest

/// The tab bar across a room's flow on the Chats stack. In an extension file so the test class stays under the
/// type-body limit, like the event and tournament classes.
extension LilyChatTests {
    /// A profile opened from a room stays in the room's flow: no tab bar, so the swipe back has nothing to hide; the
    /// pops under it keep the hide until the room's own, which brings the bar back on the Chats root.
    @MainActor
    func testAProfileOpenedFromARoomKeepsTheTabBarHidden() {
        tapSignInWithApple()
        openRoom(MockIDs.martaConversationRow, titled: "Marta")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForNonExistence(timeout: 5), "a room hides the bar")

        app.buttons["chat-title"].tap()
        XCTAssertTrue(app.staticTexts["Groups in common"].waitForExistence(timeout: 10), "the profile opened")

        XCTAssertFalse(app.buttons["profile-message"].waitForExistence(timeout: 1),
                       "a profile reached from its chat offers no Message")
        XCTAssertFalse(app.tabBars.buttons["Home"].waitForExistence(timeout: 1),
                       "the profile pushed over the room keeps the bar away")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat-composer"].waitForExistence(timeout: 10), "back on the room")
        XCTAssertFalse(app.tabBars.buttons["Home"].waitForExistence(timeout: 1),
                       "the room under the popped cover still hides the bar")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout: 5), "back on the Chats root")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5), "the room's pop brings the bar back")
    }
}
