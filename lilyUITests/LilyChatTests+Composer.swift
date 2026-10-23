import XCTest

/// The composer's keyboard across the screens a room opens; a test in an extension is discovered only when `@objc`.
extension LilyChatTests {
    /// Coming back from the group's screen does not bring the keyboard back by itself (UIKit would, and left the
    /// composer under it); a tap on the field does, with the composer above the keyboard.
    @objc @MainActor
    func testTheKeyboardStaysDownAfterComingBackToTheRoom() {
        tapSignInWithApple()
        openChatsTab()
        openRoom("group-row-mock-group-kickers", titled: "Kreuzberg Kickers")
        let composer = app.descendants(matching: .any)["chat-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10))
        composer.tap()
        XCTAssertTrue(waitForKeyboardFocus(composer))
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))

        app.buttons["chat-title"].tap()
        XCTAssertTrue(app.buttons["group-invite"].waitForExistence(timeout: 10), "the group's screen opens")
        XCTAssertTrue(keyboard.waitForNonExistence(timeout: 5), "the group's screen has no keyboard")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(composer.waitForExistence(timeout: 5), "back in the room")
        XCTAssertFalse(keyboard.waitForExistence(timeout: 3), "the keyboard does not come back by itself")

        composer.tap()
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForKeyboardFocus(composer))
        waitUntilHittableAndStill(composer)
        XCTAssertLessThanOrEqual(composer.frame.maxY, keyboard.frame.minY, "the composer sits above the keyboard")
    }
}
