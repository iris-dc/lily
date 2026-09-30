import XCTest

/// People against the mock repositories: who is in a game and the profile a participant row opens, a public group's
/// roster read by someone who is not in the group, and direct conversations (started from a profile, or the fixture
/// one with Marta on the Chats tab). Identifiers mirror `AccessibilityIdentifiers(+People)`; the mock ids mirror
/// `MockGroupFixtures`.
final class LilyPeopleTests: LilyUITestCase {
    let martaRow = "participant-row-mock-user-marta"
    let jonasRow = "participant-row-mock-user-jonas"
    let basketballRow = "group-row-mock-group-basketball"
    let kickersRow = "group-row-mock-group-kickers"
    let devMemberRow = "member-row-mock-user-dev"
    let martaConversationRow = "group-row-mock-dm-mock-user-marta"
    let jonasConversationRow = "group-row-mock-dm-mock-user-jonas"

    /// "Sunset 5-a-side" is hosted by Marta, who shares Kreuzberg Kickers with the caller.
    @MainActor
    func testEventDetailListsParticipantsAndOpensAProfile() {
        tapSignInWithApple()
        openSunsetParticipants()
        let host = app.buttons[martaRow]
        XCTAssertTrue(host.waitForExistence(timeout: 5), "the host leads the list")
        XCTAssertTrue(host.label.contains("Host"), "the host's row carries the chip: \(host.label)")
        scrollUntilHittable(host)
        host.tap()

        XCTAssertTrue(app.navigationBars["Marta"].waitForExistence(timeout: 10), "the row opens the person's profile")
        XCTAssertTrue(app.buttons["profile-message"].waitForExistence(timeout: 5), "another person can be messaged")
        XCTAssertTrue(app.staticTexts["Groups in common"].exists)
        XCTAssertTrue(app.buttons[kickersRow].waitForExistence(timeout: 10), "Marta and the caller share Kreuzberg Kickers")
    }

    /// Berlin Basketball is public and the caller is not in it: the Members segment is there, its rows open profiles,
    /// and the caller has no row of their own.
    @MainActor
    func testPublicGroupRosterIsVisibleToNonMembers() {
        tapSignInWithApple()
        let carousel = app.scrollViews["group-carousel"]
        XCTAssertTrue(carousel.waitForExistence(timeout: 10), "the carousel shows once Discover answered")
        let basketball = app.buttons[basketballRow]
        XCTAssertTrue(basketball.waitForExistence(timeout: 10))
        // The second column of tiles peeks in at the right edge; one swipe aligns it.
        carousel.swipeLeft()
        waitUntilHittableAndStill(basketball)
        basketball.tap()

        XCTAssertTrue(app.buttons["group-join"].waitForExistence(timeout: 5), "the caller is not a member")
        let picker = app.segmentedControls["group-section"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "a public roster is offered to a signed-in outsider")
        picker.buttons["Members"].tap()

        let dev = app.buttons[devMemberRow]
        XCTAssertTrue(dev.waitForExistence(timeout: 10), "Dev owns Berlin Basketball")
        XCTAssertTrue(app.buttons["member-row-mock-user-marta"].exists)
        XCTAssertFalse(labelled("You").exists, "an outsider has no row of their own")
        dev.tap()
        XCTAssertTrue(app.navigationBars["Dev"].waitForExistence(timeout: 10), "a roster row opens the person's profile")
        XCTAssertTrue(app.buttons["profile-message"].waitForExistence(timeout: 5))
    }

    /// "Message" on a profile opens the direct conversation, a chat titled with the person, on the Chats stack; the
    /// Chats tab then lists it as a person row captioned "Direct message". Jonas has no conversation in the fixtures,
    /// so this one is started here.
    @MainActor
    func testProfileMessageButtonOpensAConversation() {
        tapSignInWithApple()
        openSunsetParticipants()
        let jonas = app.buttons[jonasRow]
        XCTAssertTrue(jonas.waitForExistence(timeout: 5), "Jonas is in the game")
        scrollUntilHittable(jonas)
        jonas.tap()
        XCTAssertTrue(app.navigationBars["Jonas"].waitForExistence(timeout: 10), "the row opens his profile")
        let message = app.buttons["profile-message"]
        XCTAssertTrue(message.waitForExistence(timeout: 5))
        message.tap()

        XCTAssertTrue(app.descendants(matching: .any)["chat-composer"].waitForExistence(timeout: 10), "a chat opens")
        XCTAssertTrue(app.navigationBars["Jonas"].exists, "the conversation is titled with the person")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout: 5), "the chat was pushed on the Chats stack")
        let row = app.buttons[jonasConversationRow]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the Chats tab lists the new conversation")
        XCTAssertTrue(row.label.contains("Direct message"), "a person row is captioned Direct message: \(row.label)")
    }

    /// The fixtures hold a conversation with Marta: the Chats tab lists her as a person row captioned "Direct message",
    /// the row opens a chat titled with her name whose info button leads to her profile (without "Message": the chat is
    /// one Back away), and Home never lists her.
    @MainActor
    func testChatsTabListsTheConversationWithMarta() {
        tapSignInWithApple()
        openChatsTab()
        let marta = app.buttons[martaConversationRow]
        XCTAssertTrue(marta.waitForExistence(timeout: 10))
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
        XCTAssertTrue(app.buttons[kickersRow].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[martaConversationRow].exists, "Home lists communities only")
    }

    /// Opens "Sunset 5-a-side" from Explore and waits for its "Who's in" list.
    @MainActor
    private func openSunsetParticipants() {
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Sunset 5-a-side")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.staticTexts["Who's in"].waitForExistence(timeout: 10), "a signed-in caller sees who is in")
    }
}
