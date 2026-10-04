import XCTest

/// Tournaments against the mock repositories: creating one from Explore's "+" and finding it on Home, entering the
/// team tournament the caller organises by naming a team, the tournament room on Chats whose info button opens the
/// tournament, a group's Tournaments segment, the organiser's start and the bracket it draws, and a player confirming
/// and reporting results. Identifiers mirror `AccessibilityIdentifiers(+Tournaments)`; the mock ids mirror
/// `MockTournamentFixtures`. Helpers in `LilyTournamentTests+Helpers.swift`.
final class LilyTournamentTests: LilyUITestCase {
    let kickersCupRow = "tournament-row-mock-tournament-kickers-cup"
    let tableTennisRow = "tournament-row-mock-tournament-table-tennis"
    let tableTennisRoom = "group-row-mock-tournament-table-tennis"
    let kickersGroupRow = "group-row-mock-group-kickers"
    /// Jonas's entry in Tuesday Table Tennis (`MockTournamentFixtures.entryID`, index 1).
    let jonasStanding = "standing-01J9ENTRYTT00000000000001"

    /// "New tournament" on Explore's "+" opens the form; a name and a place complete it (the spot comes from the mock
    /// location); the organiser lands on the new tournament's detail on Home, and Home lists it under "Your tournaments".
    @MainActor
    func testCreatingATournamentFromExploreShowsItOnHome() {
        tapSignInWithApple()
        tapCreateMenuItem("New tournament")
        XCTAssertTrue(app.navigationBars["New tournament"].waitForExistence(timeout: 5))

        let name = "Canal Cup"
        enter(name, into: app.textFields["tournament-name"])
        enter("Canal Path", into: app.textFields["tournament-location-name"])
        let submit = app.buttons["tournament-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isEnabled, "a name and a place complete the draft")
        submit.tap()

        XCTAssertTrue(app.navigationBars["New tournament"].waitForNonExistence(timeout: 10), "the sheet must close once created")
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 10), "the organiser lands on the new tournament")
        XCTAssertTrue(app.staticTexts["You organise this tournament"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tournament-join"].exists, "an individual tournament offers Join to its organiser too")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your tournaments"].waitForExistence(timeout: 10))
        XCTAssertTrue(labelled(name).waitForExistence(timeout: 10), "the new tournament must be listed on Home")
    }

    /// The caller organises the Kickers Cup, a 5-a-side bracket in registration, and has not entered: "Create team"
    /// opens the team-name sheet, and the named team lands on the Teams segment while the control turns into Leave.
    @MainActor
    func testJoiningATeamTournamentCreatesATeam() {
        tapSignInWithApple()
        openKickersCup()

        createTeam(named: "Late Bloomers")

        XCTAssertTrue(labelled("Late Bloomers").exists, "the Teams segment lists the new team")
        XCTAssertTrue(labelled("5 of 8 teams").exists, "the count moved")
    }

    /// The organiser enters a fifth team and starts the Kickers Cup from its menu, after the confirmation that names
    /// the entries: the bracket of eight comes up with its three byes, the one first-round match, the semi-finals
    /// waiting on it and the final, and registration is closed.
    @MainActor
    func testOrganizerStartsAndTheBracketShows() {
        tapSignInWithApple()
        openKickersCup()
        createTeam(named: "Late Bloomers")

        app.buttons["tournament-more"].tap()
        let start = app.buttons["tournament-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "the organiser's menu offers Start")
        XCTAssertTrue(start.isEnabled, "five teams are enough to start")
        start.tap()
        XCTAssertTrue(app.staticTexts["Start Kickers Cup?"].waitForExistence(timeout: 5), "the confirmation names it")
        XCTAssertTrue(labelled("5 of 8 teams are in").exists, "and the entries")
        app.sheets.firstMatch.buttons["Start tournament"].tap()

        XCTAssertTrue(app.staticTexts["In progress"].waitForExistence(timeout: 10), "the status moved")
        let bye = app.buttons["match-r01p001"]
        XCTAssertTrue(bye.waitForExistence(timeout: 10), "the bracket shows right after the start")
        XCTAssertTrue(bye.label.contains("Görli Giants") && bye.label.contains("Bye"), "seed 1 gets a bye: \(bye.label)")
        let played = app.buttons["match-r01p002"]
        XCTAssertTrue(played.label.contains("Hasenheide United") && played.label.contains("Late Bloomers"),
                      "seeds 4 and 5 meet in the only first-round match: \(played.label)")
        XCTAssertTrue(app.buttons["match-r02p002"].label.contains("Late Tackles"), "a bye's winner stands in the semi-final")
        XCTAssertTrue(app.staticTexts["Quarter-finals"].exists && app.staticTexts["Final"].exists, "the rounds are titled")
        XCTAssertFalse(app.buttons["tournament-leave"].exists, "registration closed with the start")
    }

    /// The caller plays Tuesday Table Tennis: Jonas reported his win over them, so that match offers Confirm, and the
    /// confirmed result lifts him to the top of the standings; their match against Dev is still to play, and the score
    /// they report there waits for Dev as "Reported".
    @MainActor
    func testConfirmingAndReportingResultsUpdateTheStandingsAndTheMatches() {
        tapSignInWithApple()
        openTableTennis()
        pickSection("Standings")
        let jonas = app.descendants(matching: .any)[jonasStanding]
        XCTAssertTrue(jonas.waitForExistence(timeout: 10), "the table lists every player")
        XCTAssertTrue(jonas.label.hasSuffix("3"), "one win so far: \(jonas.label)")

        pickSection("Matches")
        openMatch("r02p003")
        XCTAssertTrue(labelled("Jonas reported 3–2").waitForExistence(timeout: 5), "the other side's report is named")
        app.buttons["match-confirm"].tap()
        XCTAssertTrue(app.navigationBars["Match"].waitForNonExistence(timeout: 10), "the sheet closes once confirmed")
        pickSection("Standings")
        XCTAssertTrue(jonas.waitForExistence(timeout: 10))
        XCTAssertTrue(jonas.label.hasPrefix("1") && jonas.label.hasSuffix("6"), "two wins lead the table: \(jonas.label)")

        pickSection("Matches")
        openMatch("r03p002")
        enter("1", into: app.textFields["match-score-a"])
        enter("3", into: app.textFields["match-score-b"])
        app.buttons["match-report"].tap()
        XCTAssertTrue(app.navigationBars["Match"].waitForNonExistence(timeout: 10), "the sheet closes once reported")
        let reported = app.buttons["match-r03p002"]
        XCTAssertTrue(reported.waitForExistence(timeout: 5))
        XCTAssertTrue(reported.label.contains("Reported"), "a side's score waits for the other side: \(reported.label)")
    }

    /// Tuesday Table Tennis is a tournament the caller plays in: its room is listed on Chats with the trophy's caption,
    /// opens the chat, and the chat's info button leads to the tournament's detail.
    @MainActor
    func testTournamentRoomIsListedOnChatsAndOpensTheDetailFromTheInfoButton() {
        tapSignInWithApple()
        openChatsTab()
        let room = app.buttons[tableTennisRoom]
        XCTAssertTrue(room.waitForExistence(timeout: 10))
        XCTAssertTrue(room.label.contains("Tournament"), "a room row is captioned Tournament: \(room.label)")
        room.tap()

        XCTAssertTrue(app.navigationBars["Tuesday Table Tennis"].waitForExistence(timeout: 10), "the row opens the room")
        XCTAssertTrue(app.staticTexts["I'll bring a box."].waitForExistence(timeout: 10), "the room's lines show")
        let info = app.buttons["chat-title"]
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        info.tap()

        XCTAssertTrue(app.staticTexts["Organised by Marta"].waitForExistence(timeout: 10), "the info button leads to it")
        XCTAssertTrue(app.segmentedControls["tournament-section"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["You're in"].exists, "the caller plays in it")
    }

    /// Kreuzberg Kickers hosts the Kickers Cup: its detail's Tournaments segment lists the card.
    @MainActor
    func testGroupDetailListsItsTournaments() {
        tapSignInWithApple()
        openHomeTab()
        let kickers = app.buttons[kickersGroupRow]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        kickers.tap()

        let picker = app.segmentedControls["group-section"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.buttons["Tournaments"].tap()

        let card = app.buttons[kickersCupRow]
        XCTAssertTrue(card.waitForExistence(timeout: 10), "the group's segment lists its tournament")
        XCTAssertTrue(card.label.contains("Kickers Cup") && card.label.contains("4 of 8 teams"), "the card: \(card.label)")
        card.tap()
        XCTAssertTrue(app.staticTexts["Hosted in Kreuzberg Kickers"].waitForExistence(timeout: 10))
    }
}
