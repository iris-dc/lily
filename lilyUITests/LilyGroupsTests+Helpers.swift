import XCTest

/// Helpers of `LilyGroupsTests`, in their own file so the test class stays under the type-body limit.
extension LilyGroupsTests {
    @MainActor
    func showDiscover() {
        let discover = app.segmentedControls["groups-scope"].buttons["Discover"]
        XCTAssertTrue(discover.waitForExistence(timeout: 5))
        discover.tap()
    }

    /// Discover lists Kreuzberg Kickers (public, the caller is a member) whatever Mine shows, so it is the way in.
    @MainActor
    func openKickersDetail() {
        openGroupsTab()
        showDiscover()
        let kickers = app.buttons[kickersRow]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        scrollUntilHittable(kickers)
        kickers.tap()
        XCTAssertTrue(app.buttons["group-create-event"].waitForExistence(timeout: 5), "a member may create games here")
    }

    /// Fills the form opened from the group detail (the spot comes from the mock location) and submits it.
    @MainActor
    func createGame(titled title: String) {
        app.buttons["group-create-event"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 5))
        enter(title, into: app.textFields["create-title"])
        enter("Görli Pitch", into: app.textFields["create-location-name"])
        let submit = app.buttons["create-submit"]
        XCTAssertTrue(submit.isEnabled, "title, place and the mock position complete the draft")
        submit.tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForNonExistence(timeout: 10), "the sheet must close once created")
    }

    /// Label and value of a row, since a form row may expose its text as either.
    @MainActor
    func text(of element: XCUIElement) -> String {
        [element.label, element.value as? String].compactMap { $0 }.joined(separator: " ")
    }
}
