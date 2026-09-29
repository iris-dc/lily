import XCTest

/// Helpers of `LilyGroupsTests`, in their own file so the test class stays under the type-body limit.
extension LilyGroupsTests {
    /// Pushes Discover from the carousel's "See all" on Explore; the carousel shows once Discover has answered.
    @MainActor
    func showDiscover() {
        let seeAll = app.buttons["groups-see-all"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10))
        seeAll.tap()
        XCTAssertTrue(app.navigationBars["Discover groups"].waitForExistence(timeout: 5))
    }

    /// Kreuzberg Kickers (public, the caller is a member) is the first tile of the carousel on Explore.
    @MainActor
    func openKickersDetail() {
        let kickers = app.buttons[kickersRow]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
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
