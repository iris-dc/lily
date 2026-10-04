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

    /// Enters a fifth team and starts the Kickers Cup from its menu, through the confirmation; the bracket is up.
    @MainActor
    func startKickersCup() {
        createTeam(named: "Late Bloomers")
        app.buttons["tournament-more"].tap()
        let start = app.buttons["tournament-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "the organiser's menu offers Start")
        XCTAssertTrue(start.isEnabled, "five teams are enough to start")
        start.tap()
        XCTAssertTrue(app.staticTexts["Start Kickers Cup?"].waitForExistence(timeout: 5), "the confirmation names it")
        app.sheets.firstMatch.buttons["Start tournament"].tap()
        XCTAssertTrue(app.staticTexts["In progress"].waitForExistence(timeout: 10), "the status moved")
    }

    /// Opens the Chats tab and pushes the inbox from its pinned row (the inbox is titled with the app's name).
    @MainActor
    func openInbox() {
        openChatsTab()
        let row = app.buttons["inbox-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["iskra"].waitForExistence(timeout: 5))
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
