import XCTest

/// The event rooms against the mock repositories: the room on Chats, its info button back to the event, the detail's
/// in-body action row with the invite sheet, and the inbox's event invite. In an extension file so the test class
/// stays under the type-body limit, as the tournament class does; the item id mirrors `MockInboxFixtures.eventInviteID`.
extension LilyEventEditTests {
    private var eventInviteID: String { "01J8MOCKNB0000000000000007" }

    /// The joined sunset fixture's room is listed on Chats with the event caption, opens on its lines, and the chat's
    /// info button leads to the event's detail, which offers no Open chat back into the room it came from.
    @MainActor
    func testEventRoomIsListedOnChatsAndOpensTheEventFromTheInfoButton() {
        tapSignInWithApple()
        let room = chatsRow(MockIDs.sunsetRoomRow)
        XCTAssertTrue(room.label.contains("Event"), "a room row is captioned Event: \(room.label)")
        room.tap()

        XCTAssertTrue(app.navigationBars["Sunset 5-a-side"].waitForExistence(timeout: 10), "the row opens the room")
        XCTAssertTrue(app.staticTexts["Gate code is 4311 if you're early."].waitForExistence(timeout: 10),
                      "the room's lines show")
        let info = app.buttons["chat-title"]
        XCTAssertTrue(info.waitForExistence(timeout: 5))
        info.tap()

        XCTAssertTrue(app.staticTexts["Hosted in Kreuzberg Kickers"].waitForExistence(timeout: 10),
                      "the info button leads to the event's detail")
        XCTAssertTrue(app.buttons["Leave"].waitForExistence(timeout: 10), "the caller is in the game")
        XCTAssertFalse(app.buttons["event-action-chat"].waitForExistence(timeout: 1),
                       "a detail reached from its own chat offers no Open chat")
    }

    /// The row's "Open chat" opens the room in place, so Back returns to the detail rather than the Chats list, and
    /// the row's "Invite" opens the invite sheet, where a sent invite reads Invited (the caller joined the sunset
    /// fixture, which has not started, so both buttons show).
    @MainActor
    func testActionRowOpensTheEventChatInPlaceAndTheInviteSheet() {
        tapSignInWithApple()
        openFromHome("Sunset 5-a-side")

        let chat = app.buttons["event-action-chat"]
        XCTAssertTrue(chat.waitForExistence(timeout: 10), "a participant gets the in-body chat button")
        chat.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat-composer"].waitForExistence(timeout: 10), "the room opens")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["Leave"].waitForExistence(timeout: 10),
                      "Back returns to the event's detail, not to the Chats list")

        let invite = app.buttons["event-action-invite"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5), "the game has not started, so the row offers Invite")
        invite.tap()
        XCTAssertTrue(app.navigationBars["Invite people"].waitForExistence(timeout: 5), "the row's Invite opens the sheet")
        let send = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'invite-send-'")).firstMatch
        XCTAssertTrue(send.waitForExistence(timeout: 10), "the shared pool offers someone")
        send.tap()
        let sent = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'invite-send-' AND label == 'Invited'")).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 10), "a sent invite reads Invited")
        app.navigationBars["Invite people"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Invite people"].waitForNonExistence(timeout: 5))
    }

    /// Accepting Noor's event invite joins the game and opens its detail; Home's Events segment lists it on the way back.
    @MainActor
    func testAcceptingAnEventInviteOpensTheDetailAndHomeListsTheEvent() {
        tapSignInWithApple()
        openInbox()
        XCTAssertTrue(labelled("Noor invited you to Doubles, all levels").waitForExistence(timeout: 10),
                      "the card names the event")
        let accept = app.buttons["inbox-accept-\(eventInviteID)"]
        XCTAssertTrue(accept.waitForExistence(timeout: 5))
        accept.tap()

        XCTAssertTrue(app.buttons["Leave"].waitForExistence(timeout: 10), "the accept joined the game; its detail is open")
        XCTAssertTrue(app.staticTexts["2 of 4 joined"].waitForExistence(timeout: 5), "the answer carries the real count")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5), "the detail was pushed on Home")
        XCTAssertTrue(app.staticTexts["Doubles, all levels"].waitForExistence(timeout: 10),
                      "Home's Events segment lists the joined game")
    }
}
