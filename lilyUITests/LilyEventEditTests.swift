import XCTest

/// The host's edit of their game against the mock repositories: Edit shows for the host alone, and a saved change
/// reaches the detail and the list behind it. Identifiers mirror `AccessibilityIdentifiers`.
final class LilyEventEditTests: LilyUITestCase {
    /// Creates a game (the mock location fills the spot) — the create lands on its detail — renames it through Edit
    /// and finds the new title on the detail and on Home.
    @MainActor
    func testHostEditsTheirGameFromTheDetail() {
        startCreating("Thursday five-a-side")
        continueToDetails()
        submitWizard()

        assertCreateLandedOnDetail("Thursday five-a-side")
        openEditSheet()
        let save = app.buttons["create-submit"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "nothing to save until something changed")

        replaceText(in: app.textFields["create-title"], with: "Friday five-a-side")
        assertBecomesEnabled(save, "a changed title is something to save")
        save.tap()
        XCTAssertTrue(app.navigationBars["Edit event"].waitForNonExistence(timeout: 10), "the sheet must close once saved")
        XCTAssertTrue(app.staticTexts["Friday five-a-side"].waitForExistence(timeout: 5), "the detail must show the new title")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Friday five-a-side"].waitForExistence(timeout: 5), "the list behind must show it too")
        XCTAssertFalse(app.staticTexts["Thursday five-a-side"].exists, "the old title must be gone")
    }

    /// Opening the map on the game's own spot is no change: the arrival settles nudge the pin by centimetres and must
    /// not turn Save on; a drag must. The row reads "Spot set" throughout: the coordinates stay on the picker screen.
    @MainActor
    func testOpeningTheMapOnAnEditedGameTurnsSaveOnOnlyAfterADrag() {
        startCreating("Map check")
        continueToDetails()
        submitWizard()
        assertCreateLandedOnDetail("Map check")
        openEditSheet()
        let save = app.buttons["create-submit"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "nothing to save until something changed")

        let row = app.descendants(matching: .any)["create-pick-on-map"].firstMatch
        scrollUntilHittable(row)
        let before = text(of: row)
        openSpotPicker(from: row)
        leaveSpotPicker()
        XCTAssertFalse(save.isEnabled, "opening the map on the spot is no change")
        XCTAssertEqual(text(of: row), before, "the spot must read as before")

        let map = openSpotPicker(from: row)
        let target = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            .press(forDuration: 0.2, thenDragTo: target, withVelocity: .default, thenHoldForDuration: 0.3)
        waitUntilHittableAndStill(map)
        leaveSpotPicker()
        assertBecomesEnabled(save, "a dragged spot is something to save")
        XCTAssertEqual(text(of: row), before, "the row still reads Spot set: the coordinates stay on the picker")
    }

    /// "At least" turns the stepper's count into the number needed, and the created game counts towards it instead of
    /// down to a cap.
    @MainActor
    func testCreatingAGameThatNeedsAtLeastSoManyCountsTowardsTheNumber() {
        startCreating("Open run")
        // Outside a `Form` the stepper is one element: its label carries the text, no separate static text.
        let stepper = app.steppers["create-capacity"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 5), "the capacity stepper is on the Players step")
        XCTAssertTrue(waitUntil(stepper, holds: "label == %@", "10 players"),
                      "the stepper names a cap until the choice changes: \(stepper.label)")

        choosePlayerLimit("At least")
        XCTAssertTrue(waitUntil(stepper, holds: "label == %@", "10 players needed"),
                      "the stepper names the number needed: \(stepper.label)")
        continueToDetails()
        submitWizard()

        assertCreateLandedOnDetail("Open run")
        XCTAssertTrue(app.staticTexts["1 joined · 10 needed"].waitForExistence(timeout: 5), "the bar counts towards the number")
    }

    /// "Any number" hides the stepper and the created game shows its count alone, with no bar to fill.
    @MainActor
    func testCreatingAGameForAnyNumberShowsTheCountAlone() {
        startCreating("Open walk")

        choosePlayerLimit("Any number")
        XCTAssertTrue(app.steppers["create-capacity"].waitForNonExistence(timeout: 5), "there is no number to step")
        XCTAssertTrue(app.staticTexts["No limit: anyone can join."].exists, "the footer explains the choice")
        continueToDetails()
        submitWizard()

        assertCreateLandedOnDetail("Open walk")
        XCTAssertTrue(app.staticTexts["1 joined"].waitForExistence(timeout: 5), "the count stands alone")
    }

    /// The edit form's type control is compact: the head of the list plus "See all", a search that
    /// reaches every type, and the current choice never hidden. The walk searches out a type beyond the top three,
    /// takes it, then expands the full flow and folds it back. Identifiers mirror the draft-type literals by hand.
    @MainActor
    func testEditTypePickerSearchesTheFullListAndExpands() {
        startCreating("Type picker check")
        continueToDetails()
        submitWizard()
        assertCreateLandedOnDetail("Type picker check")
        openEditSheet()

        let search = app.textFields["draft-type-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5), "the edit form shows the type search")
        XCTAssertTrue(app.buttons["draft-type-football"].waitForExistence(timeout: 5),
                      "the head of the list shows while collapsed")
        XCTAssertTrue(app.buttons["draft-type-tennis"].exists)
        XCTAssertFalse(app.buttons["draft-type-yoga"].exists, "a type beyond the top three hides until searched")
        let expander = app.buttons["draft-type-expand"]
        XCTAssertTrue(expander.exists, "the collapsed chips end on See all")

        enter("yoga", into: search)
        let yoga = app.buttons["draft-type-yoga"]
        XCTAssertTrue(yoga.waitForExistence(timeout: 5), "the search reaches a type beyond the top three")
        XCTAssertTrue(app.buttons["draft-type-football"].waitForNonExistence(timeout: 5), "only matches show while searching")
        XCTAssertFalse(expander.exists, "a search already reaches the whole list, no expander")
        yoga.tap()
        XCTAssertTrue(waitUntil(yoga, holds: "isSelected == true"), "the draft takes the searched type")
        assertBecomesEnabled(app.buttons["create-submit"], "a changed type is something to save")

        replaceText(in: search, with: "")
        XCTAssertTrue(yoga.waitForExistence(timeout: 5), "the current choice is never hidden while collapsed")
        XCTAssertTrue(app.buttons["draft-type-football"].waitForExistence(timeout: 5))
        XCTAssertTrue(expander.waitForExistence(timeout: 5))
        expander.tap()
        XCTAssertTrue(app.buttons["draft-type-hockey"].waitForExistence(timeout: 5), "See all reveals the full flow")
        XCTAssertTrue(expander.exists, "the trailing chip turns into Show less")
        expander.tap()
        XCTAssertTrue(app.buttons["draft-type-hockey"].waitForNonExistence(timeout: 5), "Show less folds the wall back")
        XCTAssertTrue(yoga.waitForExistence(timeout: 5), "the current choice is never hidden when folded")
    }

    /// Signs in, opens the wizard through the "+" menu's "New event" and walks to its Players step (the spot comes
    /// from the mock location), where the player fields live; Details follows with the submit button, and the edit
    /// tests then reopen the created game through the edit form.
    @MainActor
    private func startCreating(_ title: String) {
        tapSignInWithApple()
        tapCreateMenuItem("New event")
        walkEventWizardToPlayers(title: title, place: "Canal Path")
    }

    /// A create lands straight on the new game's detail, so the walks assert the landing
    /// instead of opening the game from Home.
    @MainActor
    private func assertCreateLandedOnDetail(_ title: String) {
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), "the create must land on the game's detail")
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
        tapAfterScrolling(app.staticTexts["Doubles, all levels"])

        XCTAssertTrue(app.buttons["Join"].waitForExistence(timeout: 5), "the detail must be open")
        XCTAssertTrue(app.buttons["event-detail-map"].waitForExistence(timeout: 5),
                      "the detail shows the spot as a map that opens Apple Maps")
        XCTAssertFalse(app.buttons["event-edit"].exists, "only the host edits")
    }

    /// Taps Edit on the open detail and waits for the sheet; the host alone sees the button.
    @MainActor
    private func openEditSheet() {
        let edit = app.buttons["event-edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "the host must see Edit")
        edit.tap()
        XCTAssertTrue(app.navigationBars["Edit event"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.navigationBars["Edit event"].waitForExistence(timeout: 5))
    }
}
