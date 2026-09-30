import XCTest

/// The host's edit of their game against the mock repositories: Edit shows for the host alone, and a saved change
/// reaches the detail and the list behind it. Identifiers mirror `AccessibilityIdentifiers`.
final class LilyEventEditTests: LilyUITestCase {
    /// Creates a game (the mock location fills the spot), opens it from Home, renames it through Edit and finds the new
    /// title on the detail and on Home. Nothing scrolls before the tab tap: a scrolled list minimises the tab bar.
    @MainActor
    func testHostEditsTheirGameFromTheDetail() {
        tapSignInWithApple()
        tapCreateButton()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 5))
        enter("Thursday five-a-side", into: app.textFields["create-title"])
        enter("Test Park", into: app.textFields["create-location-name"])
        app.buttons["create-submit"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForNonExistence(timeout: 10), "the sheet must close once created")

        app.tabBars.buttons["Home"].tap()
        let card = app.staticTexts["Thursday five-a-side"]
        if !card.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the hosted game must be listed under Home")
        card.tap()

        let edit = app.buttons["event-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "the host must see Edit")
        edit.tap()
        XCTAssertTrue(app.navigationBars["Edit game"].waitForExistence(timeout: 5))
        let save = app.buttons["create-submit"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "nothing to save until something changed")

        replaceText(in: app.textFields["create-title"], with: "Friday five-a-side")
        XCTAssertTrue(save.isEnabled, "a changed title is something to save")
        save.tap()
        XCTAssertTrue(app.navigationBars["Edit game"].waitForNonExistence(timeout: 10), "the sheet must close once saved")
        XCTAssertTrue(app.staticTexts["Friday five-a-side"].waitForExistence(timeout: 5), "the detail must show the new title")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Friday five-a-side"].waitForExistence(timeout: 5), "the list behind must show it too")
        XCTAssertFalse(app.staticTexts["Thursday five-a-side"].exists, "the old title must be gone")
    }

    @MainActor
    func testAParticipantSeesNoEditButton() {
        tapSignInWithApple()
        let card = app.staticTexts["Doubles, all levels"]
        if !card.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        XCTAssertTrue(app.buttons["Join"].waitForExistence(timeout: 5), "the detail must be open")
        XCTAssertFalse(app.buttons["event-edit"].exists, "only the host edits")
    }

    /// Puts the cursor at the end of the field's text, deletes it and types the replacement; the only way to replace a
    /// field's text that does not depend on the edit menu.
    @MainActor
    private func replaceText(in field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "missing text field")
        let current = field.value as? String ?? ""
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        field.typeText(text)
    }
}
