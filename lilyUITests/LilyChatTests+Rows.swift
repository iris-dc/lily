import XCTest

/// The Chats rows' own actions, split out because `LilyChatTests.swift` is at SwiftLint's file-length limit. A test
/// declared in an extension is discovered by XCTest only when it is `@objc`.
extension LilyChatTests {
    /// A clear asked from a room's row (its context menu) and confirmed there: the room is read at once, its row stays
    /// on the Chats tab (only a conversation's row leaves), and the room opens without its history.
    @objc @MainActor
    func testClearingARoomFromItsRowKeepsTheRowClearsItsDotAndEmptiesTheRoom() {
        tapSignInWithApple()
        openChatsTab()
        let kickers = app.buttons["group-row-mock-group-kickers"]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        let dot = kickers.descendants(matching: .any)["Unread messages"]
        XCTAssertTrue(dot.waitForExistence(timeout: 10), "the fixture room is unread before the clear")

        waitUntilHittableAndStill(kickers)
        let clear = app.buttons["chat-clear"]
        openContextMenu(on: kickers, until: clear)
        clear.tap()
        let confirmation = app.sheets.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "the confirmation asks first")
        confirmation.buttons["Clear chat"].tap()

        XCTAssertTrue(dot.waitForNonExistence(timeout: 5), "a clear marks the room read")
        XCTAssertTrue(kickers.exists, "a group's row stays; only a conversation's leaves")
        kickers.tap()
        XCTAssertTrue(app.navigationBars["Kreuzberg Kickers"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No messages yet"].waitForExistence(timeout: 10), "the cleared room opens empty")
    }
}
