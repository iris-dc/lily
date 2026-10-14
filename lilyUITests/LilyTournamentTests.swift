import XCTest

/// Tournaments against the mock repositories: creating one from Explore's "+", entering with a team, the room on Chats,
/// a group's Tournaments segment, the start and the bracket it draws, results and standings, the inbox's invite and
/// match reminder, the organiser's schedule for a match, and Discover. Identifiers mirror
/// `AccessibilityIdentifiers(+Tournaments, +Inbox)`; the mock ids mirror `MockTournamentFixtures` and
/// `MockInboxFixtures`. Helpers in `LilyTournamentTests+Helpers.swift`.
final class LilyTournamentTests: LilyUITestCase {
    let kickersCupRow = "tournament-row-mock-tournament-kickers-cup"
    let tableTennisRow = "tournament-row-mock-tournament-table-tennis"
    let padelOpenRow = "tournament-row-mock-tournament-padel-open"
    let tableTennisRoom = "group-row-mock-tournament-table-tennis"
    let padelOpenRoom = "group-row-mock-tournament-padel-open"
    let kickersGroupRow = "group-row-mock-group-kickers"
    /// Jonas's entry in Tuesday Table Tennis (`MockTournamentFixtures.entryID`, index 1).
    let jonasStanding = "standing-01J9ENTRYTT00000000000001"
    /// Noor's invite into the Padel Open, the oldest mock inbox item.
    let tournamentInviteID = "01J8MOCKNB0000000000000001"
    /// The reminder for the caller's round-three table-tennis match against Dev (`MockInboxFixtures.matchReminderID`,
    /// index 3).
    let matchReminderID = "01J8MOCKNB0000000000000003"

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
        assertBecomesEnabled(submit, "a name and a place complete the draft")
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
        startKickersCup()

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

    /// The organiser sets a time and a place for the only first-round match of the started Kickers Cup: Save closes the
    /// match sheet, and the match's row on the Matches list reads "Scheduled" with the place (the venue, prefilled).
    @MainActor
    func testOrganizerSchedulesAMatchAndTheMatchShowsTheTime() {
        tapSignInWithApple()
        openKickersCup()
        startKickersCup()

        pickSection("Matches")
        openMatch("r01p002")
        let schedule = app.buttons["match-schedule"]
        XCTAssertTrue(schedule.waitForExistence(timeout: 5), "the organiser's sheet offers Schedule")
        schedule.tap()
        XCTAssertTrue(app.navigationBars["Schedule match"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["match-location-name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["match-location-name"].value as? String, "Görlitzer Park pitch", "the venue is prefilled")
        app.buttons["match-schedule-save"].tap()

        XCTAssertTrue(app.navigationBars["Match"].waitForNonExistence(timeout: 10), "the sheet closes once scheduled")
        let row = app.buttons["match-r01p002"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Scheduled") && row.label.contains("Görlitzer Park pitch"), "the row: \(row.label)")
    }

    /// Noor's invite into her Padel Open sits in the inbox with the trophy and the tournament's shape; Accept enters the
    /// caller and opens the tournament's detail on Home, where Leave shows (registration is open); back in the inbox the
    /// card says "You joined".
    @MainActor
    func testAcceptingATournamentInviteOpensTheDetail() {
        tapSignInWithApple()
        acceptPadelOpenInvite()
        XCTAssertTrue(app.staticTexts["Organised by Noor"].exists)

        // The Chats stack still shows the inbox (which hides the tab bar), so the tab alone brings it back.
        selectTab("Chats")
        XCTAssertTrue(app.navigationBars["iskra"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["You joined"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["inbox-accept-\(tournamentInviteID)"].exists, "an answered invite offers no Accept")
    }

    /// The match reminder in the inbox opens Tuesday Table Tennis on its Matches segment with the named match's sheet
    /// up, once; Done leaves the detail on Matches.
    @MainActor
    func testMatchReminderInTheInboxOpensTheMatchSheet() {
        tapSignInWithApple()
        openInbox()
        let reminder = app.buttons["inbox-item-\(matchReminderID)"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 10), "the inbox lists the match reminder")
        XCTAssertTrue(labelled("vs Dev").waitForExistence(timeout: 5), "the card names the opponent")
        reminder.tap()
        let sheetBar = app.navigationBars["Match"]
        XCTAssertTrue(sheetBar.waitForExistence(timeout: 10), "the linked match's sheet is up")
        XCTAssertTrue(app.buttons["match-report"].waitForExistence(timeout: 5),
                      "the caller's scheduled match takes a result")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Tuesday Table Tennis"].waitForExistence(timeout: 5),
                      "the detail is the reminder's tournament")
        XCTAssertTrue(app.segmentedControls["tournament-section"].buttons["Matches"].isSelected,
                      "the detail opened on Matches")
    }

    /// Entering and leaving move the tournament's room on Chats at once: the accept of Noor's invite lists the Padel
    /// Open's room, and Leave from the detail takes it off again without waiting for Mine's next stale load.
    @MainActor
    func testLeavingATournamentFromTheDetailRemovesItsRoomFromChats() {
        tapSignInWithApple()
        acceptPadelOpenInvite()
        selectTab("Chats")
        XCTAssertTrue(app.navigationBars["iskra"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let room = app.buttons[padelOpenRoom]
        XCTAssertTrue(room.waitForExistence(timeout: 10), "the accept put the room on Chats")

        selectTab("Home")
        XCTAssertTrue(app.navigationBars["Padel Open"].waitForExistence(timeout: 5), "the detail is still up on Home")
        let leave = app.buttons["tournament-leave"]
        scrollUntilHittable(leave)
        leave.tap()
        app.sheets.firstMatch.buttons["Leave tournament"].tap()
        XCTAssertTrue(app.buttons["tournament-join"].waitForExistence(timeout: 10), "the caller is out")

        // The scroll down to Leave minimised the tab bar; `openChatsTab()` expands it again before it looks for the tab.
        openChatsTab()
        XCTAssertTrue(room.waitForNonExistence(timeout: 10), "the room left Chats with the entry")
    }

    /// Tuesday Table Tennis is a tournament the caller plays in: its room is listed on Chats with the trophy's caption,
    /// opens the chat, and the chat's info button leads to the tournament's detail.
    @MainActor
    func testTournamentRoomIsListedOnChatsAndOpensTheDetailFromTheInfoButton() {
        tapSignInWithApple()
        let room = chatsRow(tableTennisRoom)
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

    /// The carousel's "See all" pushes Discover, which lists every public tournament open for entries: the Kickers Cup,
    /// but neither Tuesday Table Tennis, which is in progress, nor the private Padel Open.
    @MainActor
    func testSeeAllOpensDiscoverTournamentsWithEveryPublicTournament() {
        relaunchAsGuest()
        let seeAll = app.buttons["tournaments-see-all"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10), "the carousel shows once the list answered")
        scrollUntilHittable(seeAll)
        seeAll.tap()
        XCTAssertTrue(app.navigationBars["Discover tournaments"].waitForExistence(timeout: 5))

        XCTAssertTrue(app.buttons[kickersCupRow].waitForExistence(timeout: 10), "a public tournament in registration")
        XCTAssertFalse(app.buttons[tableTennisRow].exists, "a tournament in progress is off Discover")
        XCTAssertFalse(app.buttons[padelOpenRow].exists, "a private tournament is off Discover")
    }
}
