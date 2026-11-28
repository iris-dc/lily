import XCTest

/// The tournament detail's pinned-bar shortcuts, mirroring the group's: Open chat and Invite for an involved caller.
/// In an extension file so the test class stays under the type-body limit, as the chat classes' files do.
extension LilyTournamentTests {
    /// The bar's "Open chat" opens the room in place, so Back returns to the detail rather than the Chats list, the
    /// Chats tab lists the room, and the bar's "Invite" opens the invite sheet (the caller organises the Kickers Cup
    /// and registration is open, so both buttons show).
    @MainActor
    func testActionRowOpensTheChatInPlaceAndTheInviteSheet() {
        tapSignInWithApple()
        openKickersCup()

        let chat = app.buttons["tournament-action-chat"]
        XCTAssertTrue(chat.waitForExistence(timeout: 10), "an involved caller gets the bar's chat button")
        chat.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat-composer"].waitForExistence(timeout: 10), "the room opens")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["people-row"].waitForExistence(timeout: 10),
                      "Back returns to the tournament's detail, not to the Chats list")

        // The detail hides the tab bar (2026-11-24), so Chats is reached by its shortcut; the detail stays up on Home.
        let room = app.buttons[MockIDs.kickersCupRoomRow]
        selectTabByShortcut(3, until: room)
        XCTAssertTrue(room.label.contains("Tournament"), "the Chats tab lists the room: \(room.label)")

        selectTab("Home")
        XCTAssertTrue(app.navigationBars["Kickers Cup"].waitForExistence(timeout: 5), "the detail is still up on Home")
        let invite = app.buttons["tournament-action-invite"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5), "registration is open, so the row offers Invite")
        invite.tap()
        let inviteBar = app.navigationBars["Invite people"]
        XCTAssertTrue(inviteBar.waitForExistence(timeout: 5), "the row's Invite opens the invite sheet")
        inviteBar.buttons["Done"].tap()
        XCTAssertTrue(inviteBar.waitForNonExistence(timeout: 5))
    }
}
