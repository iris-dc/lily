import XCTest

/// Helpers of `LilyGroupsTests`, in their own file so the test class stays under the type-body limit.
extension LilyGroupsTests {
    /// Kreuzberg Kickers (public, the caller is a member) heads the carousel's second column on Explore, which peeks in
    /// at the right edge far enough to tap.
    @MainActor
    func openKickersDetail() {
        let kickers = app.buttons[MockIDs.kickersRow]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        kickers.tap()
        XCTAssertTrue(app.buttons["group-create-event"].waitForExistence(timeout: 5), "a member may create games here")
    }

    /// Fills the form opened from the group detail (the spot comes from the mock location) and submits it.
    @MainActor
    func createGame(titled title: String) {
        app.buttons["group-create-event"].tap()
        XCTAssertTrue(app.navigationBars["New event"].waitForExistence(timeout: 5))
        enter(title, into: app.textFields["create-title"])
        enter("Görli Pitch", into: app.textFields["create-location-name"])
        let submit = app.buttons["create-submit"]
        assertBecomesEnabled(submit, "title, place and the mock position complete the draft")
        submit.tap()
        XCTAssertTrue(app.navigationBars["New event"].waitForNonExistence(timeout: 10), "the sheet must close once created")
    }
}
