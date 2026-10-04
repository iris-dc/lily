import XCTest

/// Tournaments against the mock repositories: creating one from Explore's "+" and finding it on Home, entering the
/// team tournament the caller organises by naming a team, the tournament room on Chats whose info button opens the
/// tournament, and a group's Tournaments segment. Identifiers mirror `AccessibilityIdentifiers(+Tournaments)`; the mock
/// ids mirror `MockTournamentFixtures`.
final class LilyTournamentTests: LilyUITestCase {
    let kickersCupRow = "tournament-row-mock-tournament-kickers-cup"
    let tableTennisRoom = "group-row-mock-tournament-table-tennis"
    let kickersGroupRow = "group-row-mock-group-kickers"

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

        let createTeam = app.buttons["tournament-create-team"]
        scrollUntilHittable(createTeam)
        createTeam.tap()
        XCTAssertTrue(app.navigationBars["Name your team"].waitForExistence(timeout: 5))
        enter("Late Bloomers", into: app.textFields["tournament-team-name"])
        let submit = app.buttons["tournament-team-submit"]
        XCTAssertTrue(submit.isEnabled, "two characters make a team name")
        submit.tap()

        XCTAssertTrue(app.navigationBars["Name your team"].waitForNonExistence(timeout: 10), "the sheet must close once entered")
        XCTAssertTrue(app.buttons["tournament-leave"].waitForExistence(timeout: 10), "an entrant may leave")
        XCTAssertTrue(labelled("Late Bloomers").exists, "the Teams segment lists the new team")
        XCTAssertTrue(labelled("5 of 8 teams").exists, "the count moved")
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

    /// Opens the Kickers Cup from Home's "Your tournaments" section.
    @MainActor
    private func openKickersCup() {
        openHomeTab()
        let card = app.buttons[kickersCupRow]
        if !card.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "Home lists the tournament the caller organises")
        scrollUntilHittable(card)
        card.tap()
        XCTAssertTrue(app.navigationBars["Kickers Cup"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["You organise this tournament"].waitForExistence(timeout: 10))
    }
}
