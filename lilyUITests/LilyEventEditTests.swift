import XCTest

/// The host's edit of their game against the mock repositories: Edit shows for the host alone, and a saved change
/// reaches the detail and the list behind it. Identifiers mirror `AccessibilityIdentifiers`.
final class LilyEventEditTests: LilyUITestCase {
    /// Creates a game (the mock location fills the spot), opens it from Home, renames it through Edit and finds the new
    /// title on the detail and on Home.
    @MainActor
    func testHostEditsTheirGameFromTheDetail() {
        startCreating("Thursday five-a-side")
        app.buttons["create-submit"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForNonExistence(timeout: 10), "the sheet must close once created")

        openFromHome("Thursday five-a-side")
        openEditSheet()
        let save = app.buttons["create-submit"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "nothing to save until something changed")

        replaceText(in: app.textFields["create-title"], with: "Friday five-a-side")
        assertBecomesEnabled(save, "a changed title is something to save")
        save.tap()
        XCTAssertTrue(app.navigationBars["Edit game"].waitForNonExistence(timeout: 10), "the sheet must close once saved")
        XCTAssertTrue(app.staticTexts["Friday five-a-side"].waitForExistence(timeout: 5), "the detail must show the new title")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Friday five-a-side"].waitForExistence(timeout: 5), "the list behind must show it too")
        XCTAssertFalse(app.staticTexts["Thursday five-a-side"].exists, "the old title must be gone")
    }

    /// Opening the map on the game's own spot is no change: the arrival settles nudge the pin by centimetres and must
    /// not turn Save on; a drag must, and the row must read the new spot.
    @MainActor
    func testOpeningTheMapOnAnEditedGameTurnsSaveOnOnlyAfterADrag() {
        startCreating("Map check")
        app.buttons["create-submit"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForNonExistence(timeout: 10), "the sheet must close once created")
        openFromHome("Map check")
        openEditSheet()
        let save = app.buttons["create-submit"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "nothing to save until something changed")

        let row = app.descendants(matching: .any)["create-pick-on-map"].firstMatch
        scrollUntilHittable(row)
        let before = spotText(of: row)
        openSpotPicker(from: row)
        leaveSpotPicker()
        XCTAssertFalse(save.isEnabled, "opening the map on the spot is no change")
        XCTAssertEqual(spotText(of: row), before, "the spot must read as before")

        let map = openSpotPicker(from: row)
        let target = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.2, thenDragTo: target, withVelocity: .default, thenHoldForDuration: 0.3)
        waitUntilHittableAndStill(map)
        leaveSpotPicker()
        assertBecomesEnabled(save, "a dragged spot is something to save")
        XCTAssertNotEqual(spotText(of: row), before, "the row must show the new spot")
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

    /// Signs in, opens the create sheet and fills the two required texts; the spot comes from the mock location. The
    /// place row is dragged into the tree first: the event-type chips push it below the fold on a 6.1-inch phone.
    @MainActor
    private func startCreating(_ title: String) {
        tapSignInWithApple()
        tapCreateButton()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 5))
        enter(title, into: app.textFields["create-title"])
        let locationName = app.textFields["create-location-name"]
        dragUpUntilExists(locationName)
        enter("Canal Path", into: locationName)
    }

    /// Taps a segment of the Players picker, scrolling it into view first; a segmented picker's segments are buttons.
    @MainActor
    private func choosePlayerLimit(_ segment: String) {
        let button = app.buttons[segment]
        scrollUntilHittable(button)
        button.tap()
    }

    /// "Doubles, all levels" is 1 of 4 and unjoined, so the caller is neither host nor participant; `canEdit` is host
    /// versus everyone else.
    @MainActor
    func testANonHostSeesNoEditButton() {
        tapSignInWithApple()
        let card = app.staticTexts["Doubles, all levels"]
        _ = card.waitForExistence(timeout: 10)
        scrollUntilHittable(card)
        card.tap()

        XCTAssertTrue(app.buttons["Join"].waitForExistence(timeout: 5), "the detail must be open")
        XCTAssertFalse(app.buttons["event-edit"].exists, "only the host edits")
    }

    /// Taps Edit on the open detail and waits for the sheet; the host alone sees the button.
    @MainActor
    private func openEditSheet() {
        let edit = app.buttons["event-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "the host must see Edit")
        edit.tap()
        XCTAssertTrue(app.navigationBars["Edit game"].waitForExistence(timeout: 5))
    }

    /// Pushes the location picker from the form's map row and returns its map once it is still.
    @MainActor
    @discardableResult
    private func openSpotPicker(from row: XCUIElement) -> XCUIElement {
        row.tap()
        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5), "the picker must open")
        waitUntilHittableAndStill(map)
        return map
    }

    /// Leaves the picker through Done and waits for the form; Done and Back keep the same spot.
    @MainActor
    private func leaveSpotPicker() {
        app.buttons["create-map-done"].tap()
        XCTAssertTrue(app.navigationBars["Edit game"].waitForExistence(timeout: 5))
    }

    /// What the map row reads, label and value together, so the coordinate counts wherever the link exposes it.
    @MainActor
    private func spotText(of row: XCUIElement) -> String {
        "\(row.label)|\(row.value as? String ?? "")"
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
