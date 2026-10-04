import XCTest

/// Helpers of `LilyTournamentTests`, in their own file so the test class stays under the type-body limit.
extension LilyTournamentTests {
    /// Opens the Kickers Cup from Home's "Your tournaments" section; the caller organises it.
    @MainActor
    func openKickersCup() {
        openTournament(row: kickersCupRow, titled: "Kickers Cup")
        XCTAssertTrue(app.staticTexts["You organise this tournament"].waitForExistence(timeout: 10))
    }

    /// Opens Tuesday Table Tennis from Home; the caller plays in it, so it is listed first (in progress).
    @MainActor
    func openTableTennis() {
        openTournament(row: tableTennisRow, titled: "Tuesday Table Tennis")
        XCTAssertTrue(app.staticTexts["You're in"].waitForExistence(timeout: 10))
    }

    /// Names a team on an open team tournament's detail and waits until the caller is in.
    @MainActor
    func createTeam(named name: String) {
        let createTeam = app.buttons["tournament-create-team"]
        scrollUntilHittable(createTeam)
        createTeam.tap()
        XCTAssertTrue(app.navigationBars["Name your team"].waitForExistence(timeout: 5))
        enter(name, into: app.textFields["tournament-team-name"])
        let submit = app.buttons["tournament-team-submit"]
        XCTAssertTrue(submit.isEnabled, "two characters make a team name")
        submit.tap()
        XCTAssertTrue(app.navigationBars["Name your team"].waitForNonExistence(timeout: 10), "the sheet must close once entered")
        XCTAssertTrue(app.buttons["tournament-leave"].waitForExistence(timeout: 10), "an entrant may leave")
    }

    /// Picks a segment of the detail's picker, scrolling back to it when the segment's content pushed it off screen.
    @MainActor
    func pickSection(_ title: String) {
        let picker = app.segmentedControls["tournament-section"]
        for _ in 0..<4 where !(picker.exists && picker.isHittable) {
            app.swipeDown()
        }
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons[title].tap()
    }

    /// Opens a match's sheet from the Matches list, scrolling to its row.
    @MainActor
    func openMatch(_ id: String) {
        let row = app.buttons["match-\(id)"]
        scrollUntilHittable(row)
        row.tap()
        XCTAssertTrue(app.navigationBars["Match"].waitForExistence(timeout: 5), "the match sheet opens")
    }

    @MainActor
    private func openTournament(row: String, titled title: String) {
        openHomeTab()
        let card = app.buttons[row]
        if !card.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Home lists the caller's tournaments")
        scrollUntilHittable(card)
        card.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
    }
}
