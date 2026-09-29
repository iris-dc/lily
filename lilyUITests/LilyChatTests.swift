import XCTest

/// The Chats tab against the mock repositories: the pinned inbox row over the caller's rooms, and the inbox itself with
/// Noor's invite into Climbing Buddies and the reminder for the first fixture game. Identifiers mirror
/// `AccessibilityIdentifiers(+Inbox)`; the item ids mirror `MockInboxFixtures`.
final class LilyChatTests: LilyUITestCase {
    let inviteID = "01J8MOCKNB0000000000000002"
    let reminderID = "01J8MOCKNB0000000000000001"

    @MainActor
    func testChatsTabShowsInboxRowAndRooms() {
        tapSignInWithApple()
        openChatsTab()

        XCTAssertTrue(app.buttons["inbox-row"].waitForExistence(timeout: 10))
        XCTAssertTrue(labelled("Noor invited you to Climbing Buddies").waitForExistence(timeout: 5),
                      "the inbox row previews its newest item")
        XCTAssertTrue(app.buttons["group-row-mock-group-kickers"].exists, "the caller's rooms follow the inbox")
    }

    /// Accepting joins the group and opens its chat on the Chats stack; on the way back the card says "You joined",
    /// and Home lists the group.
    @MainActor
    func testAcceptingAnInviteFromTheInboxOpensTheGroupChat() {
        tapSignInWithApple()
        openInbox()
        let accept = app.buttons["inbox-accept-\(inviteID)"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10))
        accept.tap()
        XCTAssertTrue(app.navigationBars["Climbing Buddies"].waitForExistence(timeout: 10), "the group's chat opens")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["iskra"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["You joined"].waitForExistence(timeout: 5))
        XCTAssertFalse(accept.exists, "an answered invite offers no Accept")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout: 5))

        openHomeTab()
        XCTAssertTrue(app.buttons["group-row-mock-group-climbing"].waitForExistence(timeout: 10), "Home lists the new group")
    }

    @MainActor
    func testDecliningAnInviteMarksItDeclined() {
        tapSignInWithApple()
        openInbox()
        let decline = app.buttons["inbox-decline-\(inviteID)"]
        XCTAssertTrue(decline.waitForExistence(timeout: 10))
        decline.tap()

        XCTAssertTrue(app.staticTexts["Declined"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["inbox-accept-\(inviteID)"].exists, "an answered invite offers no Accept")
        XCTAssertFalse(decline.exists)
    }

    /// The reminder card opens the game's detail on the same stack.
    @MainActor
    func testReminderInTheInboxOpensTheGame() {
        tapSignInWithApple()
        openInbox()
        let reminder = app.buttons["inbox-item-\(reminderID)"]
        XCTAssertTrue(reminder.waitForExistence(timeout: 10))
        reminder.tap()

        XCTAssertTrue(app.staticTexts["Hosted in Kreuzberg Kickers"].waitForExistence(timeout: 10), "the game's detail opens")
        XCTAssertTrue(app.staticTexts["Sunset 5-a-side"].exists)
    }

    /// Opens the Chats tab and pushes the inbox from its pinned row (the inbox is titled with the app's name).
    @MainActor
    private func openInbox() {
        openChatsTab()
        let row = app.buttons["inbox-row"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.navigationBars["iskra"].waitForExistence(timeout: 5))
    }
}
