import XCTest

/// People against the mock repositories: who is in a game and the profile a participant row opens (the bio, the groups,
/// games and tournaments in common), a public group's
/// roster read by someone who is not in the group, and direct conversations (started from a profile, or the fixture
/// one with Marta on the Chats tab). Identifiers mirror `AccessibilityIdentifiers(+People)`; the mock ids mirror
/// `MockGroupFixtures`.
final class LilyPeopleTests: LilyUITestCase {
    /// "Sunset 5-a-side" is hosted by Marta, who shares Kreuzberg Kickers with the caller.
    @MainActor
    func testEventDetailListsParticipantsAndOpensAProfile() {
        tapSignInWithApple()
        openSunsetParticipants()
        let host = app.buttons[MockIDs.martaRow]
        XCTAssertTrue(host.waitForExistence(timeout: 5), "the host leads the list")
        XCTAssertTrue(host.label.contains("Host"), "the host's row carries the chip: \(host.label)")
        tapAfterScrolling(host)

        XCTAssertTrue(app.navigationBars["Marta"].waitForExistence(timeout: 10), "the row opens the person's profile")
        XCTAssertTrue(app.buttons["profile-message"].waitForExistence(timeout: 5), "another person can be messaged")
        XCTAssertTrue(app.staticTexts["Padel on Sundays, football when it rains."].waitForExistence(timeout: 10),
                      "her bio shows under her name")
        XCTAssertTrue(app.staticTexts["Groups in common"].exists)
        XCTAssertTrue(app.buttons[MockIDs.kickersRow].waitForExistence(timeout: 10),
                      "Marta and the caller share Kreuzberg Kickers")
        let game = app.descendants(matching: .any)[MockIDs.sunsetSharedEventRow]
        dragUpUntilExists(game)
        XCTAssertTrue(game.exists, "the game she hosts and the caller joined is a game together")
        XCTAssertTrue(app.staticTexts["Games together"].exists)
        let tableTennis = app.buttons[MockIDs.tableTennisRow]
        dragUpUntilExists(tableTennis)
        XCTAssertTrue(tableTennis.exists, "the table tennis she organises and the caller plays is a tournament together")
        tableTennis.tap()
        XCTAssertTrue(app.navigationBars["Tuesday Table Tennis"].waitForExistence(timeout: 10),
                      "the row opens the tournament")
    }

    /// Berlin Basketball is public and the caller is not in it: the Members segment is there, its rows open profiles,
    /// and the caller has no row of their own.
    @MainActor
    func testPublicGroupRosterIsVisibleToNonMembers() {
        tapSignInWithApple()
        let carousel = app.scrollViews["group-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 10), "the carousel shows once Discover answered")
        // Nearest first around the mock position: Berlin Basketball is the second tile of the first column.
        let basketball = app.buttons[MockIDs.basketballRow]
        XCTAssertTrue(basketball.waitForExistence(timeout: 10))
        waitUntilHittableAndStill(basketball)
        basketball.tap()

        XCTAssertTrue(app.buttons["group-join"].waitForExistence(timeout: 5), "the caller is not a member")
        let picker = app.segmentedControls["group-section"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "a public roster is offered to a signed-in outsider")
        picker.buttons["Members"].tap()

        let dev = app.buttons[MockIDs.devMemberRow]
        XCTAssertTrue(dev.waitForExistence(timeout: 10), "Dev owns Berlin Basketball")
        XCTAssertTrue(app.buttons[MockIDs.martaMemberRow].exists)
        // mock-apple is the mock Apple user's id (MockAuthService); a label match on "You" would also hit the hints.
        XCTAssertFalse(app.buttons[MockIDs.appleMemberRow].exists, "an outsider has no row of their own")
        dev.tap()
        XCTAssertTrue(app.navigationBars["Dev"].waitForExistence(timeout: 10), "a roster row opens the person's profile")
        XCTAssertTrue(app.buttons["profile-message"].waitForExistence(timeout: 5))
    }

    /// "Message" on a profile opens the direct conversation in place, a chat titled with the person on the same stack,
    /// so Back returns to the profile; the Chats tab still lists it as a person row captioned "Direct message". Jonas
    /// has no conversation in the fixtures, so this one is started here.
    @MainActor
    func testProfileMessageButtonOpensAConversation() {
        tapSignInWithApple()
        openSunsetParticipants()
        tapAfterScrolling(app.buttons[MockIDs.jonasRow], "Jonas is in the game")
        XCTAssertTrue(app.navigationBars["Jonas"].waitForExistence(timeout: 10), "the row opens his profile")
        let message = app.buttons["profile-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()

        XCTAssertTrue(app.descendants(matching: .any)["chat-composer"].waitForExistence(timeout: 10), "a chat opens")
        XCTAssertTrue(app.navigationBars["Jonas"].exists, "the conversation is titled with the person")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(message.waitForExistence(timeout: 5), "Back returns to the profile, not to the Chats list")
        XCTAssertTrue(app.staticTexts["Groups in common"].exists)
        openChatsTab()
        let row = chatsRow(MockIDs.jonasConversationRow)
        XCTAssertTrue(row.label.contains("Direct message"), "a person row is captioned Direct message: \(row.label)")
    }

    /// The fixtures hold a conversation with Marta: the Chats tab lists her as a person row captioned "Direct message",
    /// the row opens a chat titled with her name whose info button leads to her profile (without "Message": the chat is
    /// one Back away), and Home never lists her.
    @MainActor
    func testChatsTabListsTheConversationWithMarta() {
        tapSignInWithApple()
        let marta = chatsRow(MockIDs.martaConversationRow)
        XCTAssertTrue(marta.label.contains("Direct message"), "a person row is captioned Direct message: \(marta.label)")
        marta.tap()

        XCTAssertTrue(app.navigationBars["Marta"].waitForExistence(timeout: 10), "the row opens the conversation")
        XCTAssertTrue(app.staticTexts["Hey! Are you coming on Sunday?"].waitForExistence(timeout: 10), "her lines show")
        let info = app.buttons["chat-title"]
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        info.tap()
        XCTAssertTrue(app.staticTexts["Groups in common"].waitForExistence(timeout: 10), "the info button leads to her profile")
        XCTAssertFalse(app.buttons["profile-message"].exists, "the conversation is one Back away, so no Message from here")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(info.waitForExistence(timeout: 5), "back in the conversation")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout: 5))
        openHomeTab()
        XCTAssertTrue(app.buttons[MockIDs.kickersRow].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[MockIDs.martaConversationRow].exists, "Home lists communities only")
    }

    /// Opens "Sunset 5-a-side" from Explore and waits for its "Who's in" list.
    @MainActor
    private func openSunsetParticipants() {
        let sunset = card(containing: "Sunset 5-a-side")
        XCTAssertTrue(sunset.waitForExistence(timeout: 10))
        sunset.tap()
        XCTAssertTrue(app.staticTexts["Who's in"].waitForExistence(timeout: 10), "a signed-in caller sees who is in")
    }
}
