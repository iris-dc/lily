import XCTest

/// Helpers of `LilyTournamentTests`, in their own file so the test class stays under the type-body limit.
extension LilyTournamentTests {
    /// Opens the Kickers Cup from Home's "Your tournaments" section; the caller organises it.
    @MainActor
    func openKickersCup() {
        openTournament(row: MockIDs.kickersCupRow, titled: "Kickers Cup")
        XCTAssertTrue(app.staticTexts["You organise this tournament"].waitForExistence(timeout: 10))
    }

    /// Opens Tuesday Table Tennis from Home; the caller plays in it, so it is listed first (in progress).
    @MainActor
    func openTableTennis() {
        openTournament(row: MockIDs.tableTennisRow, titled: "Tuesday Table Tennis")
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
        assertBecomesEnabled(submit, "two characters make a team name")
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
        assertBecomesEnabled(start, "five teams are enough to start")
        start.tap()
        XCTAssertTrue(app.staticTexts["Start Kickers Cup?"].waitForExistence(timeout: 5), "the confirmation names it")
        confirm("Start tournament")
        XCTAssertTrue(app.staticTexts["In progress"].waitForExistence(timeout: 10), "the status moved")
    }

    /// Accepts Noor's invite into the Padel Open from the inbox and waits for its detail with the caller entered.
    @MainActor
    func acceptPadelOpenInvite() {
        openInbox()
        XCTAssertTrue(labelled("Padel · Round robin · Individuals").waitForExistence(timeout: 10), "the invite names the shape")
        let accept = app.buttons["inbox-accept-\(tournamentInviteID)"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5))
        accept.tap()
        XCTAssertTrue(app.navigationBars["Padel Open"].waitForExistence(timeout: 10), "the tournament's detail opens")
        XCTAssertTrue(app.buttons["tournament-leave"].waitForExistence(timeout: 10), "the accept entered the caller")
    }

    /// Walks the tournament wizard from its Name step to Details: the name, the Type and Format cards (which
    /// auto-advance), Next past Schedule, the Hosting group choice (present from Explore), the place picked from
    /// its suggestion (typed text alone is no place since round 5), then Entries and Who can join on their defaults.
    @MainActor
    func walkTournamentWizard(name: String, place: String) {
        waitForWizardStep("Name")
        enter(name, into: app.textFields["tournament-name"])
        tapNext()
        pickWizardCard("create-type-football", on: "Type")
        pickWizardCard("create-format-single_elimination", on: "Format")
        waitForWizardStep("Schedule")
        tapNext()
        waitForWizardStep("Hosting group")
        tapNext()
        waitForWizardStep("Place")
        enterPlaceAndPickSuggestion(place, into: app.textFields["tournament-location-name"])
        tapNext()
        waitForWizardStep("Entries")
        tapNext()
        waitForWizardStep("Who can join")
        tapNext()
        waitForWizardStep("Details")
    }

    /// Submits the walked tournament wizard from its Details step and waits for it to close on the answer.
    @MainActor
    func submitTournamentWizard() {
        let submit = app.buttons["tournament-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        assertBecomesEnabled(submit, "the walked draft must be complete")
        submit.tap()
        XCTAssertTrue(app.navigationBars["Details"].waitForNonExistence(timeout: 10), "the wizard must close once created")
    }

    /// Picks a segment of the detail's picker, scrolling back to it when the segment's content pushed it off screen.
    @MainActor
    func pickSection(_ title: String) {
        let picker = app.segmentedControls["tournament-section"]
        scrollUntilHittable(picker, direction: .down, maxSwipes: 4)
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

    /// Opens a tournament's detail from the card `row` under Home's "Your tournaments".
    @MainActor
    private func openTournament(row: String, titled title: String) {
        openFromHome(app.buttons[row])
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10))
    }
}
