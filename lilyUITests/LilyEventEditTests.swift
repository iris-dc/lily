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

    /// "At least" turns the stepper's count into the number needed, and the created game counts towards it instead of
    /// down to a cap.
    @MainActor
    func testCreatingAGameThatNeedsAtLeastSoManyCountsTowardsTheNumber() {
        startCreating("Open run")
        XCTAssertTrue(app.staticTexts["10 players"].exists, "the stepper names a cap until the choice changes")

        choosePlayerLimit("At least")
        XCTAssertTrue(app.staticTexts["10 players needed"].waitForExistence(timeout: 5), "the stepper names the number needed")
        app.buttons["create-submit"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForNonExistence(timeout: 10), "the sheet must close once created")

        openFromHome("Open run")
        XCTAssertTrue(app.staticTexts["1 joined · 10 needed"].waitForExistence(timeout: 5), "the bar counts towards the number")
    }

    /// "Any number" hides the stepper and the created game shows its count alone, with no bar to fill.
    @MainActor
    func testCreatingAGameForAnyNumberShowsTheCountAlone() {
        startCreating("Open walk")

        choosePlayerLimit("Any number")
        XCTAssertTrue(app.staticTexts["10 players"].waitForNonExistence(timeout: 5), "there is no number to step")
        XCTAssertTrue(app.staticTexts["No limit: anyone can join."].exists, "the footer explains the choice")
        app.buttons["create-submit"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForNonExistence(timeout: 10), "the sheet must close once created")

        openFromHome("Open walk")
        XCTAssertTrue(app.staticTexts["1 joined"].waitForExistence(timeout: 5), "the count stands alone")
    }

    /// Signs in, opens the create sheet and fills the two required texts; the spot comes from the mock location.
    @MainActor
    private func startCreating(_ title: String) {
        tapSignInWithApple()
        tapCreateButton()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 5))
        enter(title, into: app.textFields["create-title"])
        enter("Canal Path", into: app.textFields["create-location-name"])
    }

    /// Taps a segment of the Players picker, scrolling it into view first; a segmented picker's segments are buttons.
    @MainActor
    private func choosePlayerLimit(_ segment: String) {
        let button = app.buttons[segment]
        if !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "missing segment \(segment)")
        button.tap()
    }

    /// Opens the created game from Home. Nothing scrolls before the tab tap: a scrolled list minimises the tab bar.
    @MainActor
    private func openFromHome(_ title: String) {
        app.tabBars.buttons["Home"].tap()
        let card = app.staticTexts[title]
        if !card.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the hosted game must be listed under Home")
        card.tap()
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
