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

    /// Walks the wizard opened from the group's detail — seeded with the kind and this group, so the Hosting group
    /// step is off the walk — and submits it (the spot comes from the mock location).
    @MainActor
    func createGame(titled title: String) {
        app.buttons["group-create-event"].tap()
        waitForWizardStep("Name")
        enter(title, into: app.textFields["create-title"])
        tapNext()
        pickWizardEventType()
        waitForWizardStep("When")
        tapNext()
        waitForWizardStep("Place")
        XCTAssertFalse(app.navigationBars["Hosting group"].exists, "the locked group leaves no group step")
        enter("Görli Pitch", into: app.textFields["create-location-name"])
        tapNext()
        waitForWizardStep("Players")
        continueToDetails()
        submitWizard()
    }
}
