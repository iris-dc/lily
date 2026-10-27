import XCTest

/// The Chats tab against the mock repositories: the inbox row over the caller's rooms, the inbox's invite and reminder
/// cards, deleting a conversation, replying, attachments and the picture viewer (helpers in
/// `LilyChatTests+Attachments.swift`). Identifiers mirror `AccessibilityIdentifiers(+Inbox, +Attachments)`; the item
/// ids mirror `MockInboxFixtures` (the tournament invite and the match reminder, ids 1 and 3, are `LilyTournamentTests`').
final class LilyChatTests: LilyUITestCase {
    let inviteID = "01J8MOCKNB0000000000000004"
    let reminderID = "01J8MOCKNB0000000000000002"

    /// The tab's badge sums the unread rooms (Kickers, the conversation with Marta) and the unseen inbox; opening a
    /// room takes its share off and leaves the inbox's.
    @MainActor
    func testChatsTabShowsInboxRowAndRooms() {
        tapSignInWithApple()
        let chats = app.tabBars.buttons["Chats"]
        XCTAssertTrue(chats.waitForExistence(timeout: 10))
        expectBadge(of: chats, toRead: "3 unread chats")
        openChatsTab()

        XCTAssertTrue(app.buttons["inbox-row"].waitForExistence(timeout: 10))
        XCTAssertTrue(labelled("Noor invited you to Climbing Buddies").waitForExistence(timeout: 5),
                      "the inbox row previews its newest item")
        XCTAssertTrue(app.buttons["group-row-mock-group-kickers"].exists, "the caller's rooms follow the inbox")

        openRoomAndComeBack("group-row-mock-group-kickers")
        expectBadge(of: chats, toRead: "2 unread chats")
    }

    /// A line sent in a room lower in the list brings the room to the top of Chats, under the pinned inbox.
    @MainActor
    func testSendingInARoomMovesItToTheTopOfChats() {
        tapSignInWithApple()
        let rooms = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'group-row-'"))
        chatsRow("group-row-mock-group-runners")
        XCTAssertEqual(rooms.firstMatch.identifier, "group-row-mock-group-kickers", "the busiest room comes first")

        openRoom("group-row-mock-group-runners", titled: "Tempelhof Runners")
        enter("Anyone running Sunday?", into: app.descendants(matching: .any)["chat-composer"])
        app.buttons["chat-send"].tap()
        XCTAssertTrue(app.staticTexts["Anyone running Sunday?"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout: 5))
        let first = NSPredicate(format: "identifier == %@", "group-row-mock-group-runners")
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: first, evaluatedWith: rooms.firstMatch)], timeout: 5),
                       .completed,
                       "the room with the latest line is first, not \(rooms.firstMatch.identifier)")
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

    /// Deleting the conversation from the room's menu, after the confirmation: the chat closes, the Chats root no
    /// longer lists Marta, and the other rooms still open.
    @MainActor
    func testDeletingTheConversationWithMartaRemovesItFromChats() {
        tapSignInWithApple()
        openRoom("group-row-mock-dm-mock-user-marta", titled: "Marta")
        let marta = app.buttons["group-row-mock-dm-mock-user-marta"]

        let more = app.buttons["chat-more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let delete = app.buttons["chat-clear"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "the room's menu offers Delete chat")
        delete.tap()
        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "the confirmation asks first")
        confirmation.buttons["Delete chat"].tap()

        XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout: 10), "the chat closes")
        XCTAssertTrue(marta.waitForNonExistence(timeout: 5), "the conversation left the Chats tab")
        let kickers = app.buttons["group-row-mock-group-kickers"]
        XCTAssertTrue(kickers.exists)
        kickers.tap()
        XCTAssertTrue(app.navigationBars["Kreuzberg Kickers"].waitForExistence(timeout: 10), "other rooms still open")
    }

    /// Replying from a bubble's menu: the composer previews the original above the field, and the sent bubble carries
    /// a quote with the original's text.
    @MainActor
    func testReplyingQuotesTheOriginalInTheBubble() {
        tapSignInWithApple()
        openRoom("group-row-mock-group-kickers", titled: "Kreuzberg Kickers")
        let original = "Anyone up for a game this week?"
        let line = app.staticTexts[original]
        XCTAssertTrue(line.waitForExistence(timeout: 10))
        // The room's first row: the transcript opens at the bottom, so bring the row on screen before the long press.
        scrollUntilHittable(line, direction: .down, maxSwipes: 6)
        let reply = app.buttons["Reply"]
        openContextMenu(on: line, until: reply)
        reply.tap()

        let preview = app.descendants(matching: .any)["chat-reply-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "the composer previews the reply")
        XCTAssertTrue(preview.staticTexts["Replying to Marta"].exists)
        XCTAssertTrue(preview.staticTexts[original].exists, "the preview quotes the original")

        let text = "Thursday works for me too"
        enter(text, into: app.descendants(matching: .any)["chat-composer"])
        app.buttons["chat-send"].tap()

        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10), "the reply shows as a bubble")
        let quotes = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'message-quote-' AND label CONTAINS %@", original))
        XCTAssertTrue(quotes.firstMatch.waitForExistence(timeout: 5), "the bubble quotes the original")
        XCTAssertTrue(preview.waitForNonExistence(timeout: 5), "the preview goes with the send")
    }

    /// Attaching a photo (the mock picker hands the bundled one over without the system sheet): the strip shows it,
    /// Send opens once it is uploaded, the sent bubble is the picture, and a tap opens the viewer.
    @MainActor
    func testAttachingPhotoSendsImageBubble() {
        let strip = attachFromKickersRoom("Photo library")
        let removes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chat-attachment-remove-'"))
        XCTAssertTrue(removes.firstMatch.waitForExistence(timeout: 5), "the tile carries its X")
        let send = app.buttons["chat-send"]
        assertBecomesEnabled(send, "Send opens once the upload is done", timeout: 10)
        send.tap()

        let pictures = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'message-attachment-image-'"))
        XCTAssertTrue(pictures.firstMatch.waitForExistence(timeout: 10), "the sent message shows the picture")
        XCTAssertTrue(strip.waitForNonExistence(timeout: 5), "the strip goes with the send")
        pictures.firstMatch.tap()

        let viewer = app.descendants(matching: .any)["attachment-viewer"]
        XCTAssertTrue(viewer.waitForExistence(timeout: 5), "a tap opens the viewer")
        let close = app.buttons["attachment-viewer-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(viewer.waitForNonExistence(timeout: 5))
    }

    /// Attaching a file (the mock picker hands the bundled document over without the files importer): the strip shows
    /// its chip, Send opens once it is uploaded, the sent bubble carries a file card, and a tap opens it in QuickLook,
    /// whose own bar names the file and offers Done (an X labelled "close" on iOS 26, under QuickLook's identifier).
    @MainActor
    func testAttachingFileShowsCardThatOpensQuickLook() {
        let strip = attachFromKickersRoom("File")
        XCTAssertTrue(strip.staticTexts["training-plan.pdf"].waitForExistence(timeout: 5), "the chip names the file")
        let send = app.buttons["chat-send"]
        assertBecomesEnabled(send, "Send opens once the upload is done", timeout: 10)
        send.tap()

        let cards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'message-attachment-file-'"))
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 10), "the sent message shows the file card")
        XCTAssertTrue(strip.waitForNonExistence(timeout: 5), "the strip goes with the send")
        cards.firstMatch.tap()

        let quickLook = app.otherElements["QLPreviewControllerView"]
        XCTAssertTrue(quickLook.waitForExistence(timeout: 10), "QuickLook opens")
        XCTAssertTrue(app.navigationBars["training-plan"].waitForExistence(timeout: 5), "QuickLook's bar names the file")
        let done = app.buttons["QLOverlayDoneButtonAccessibilityIdentifier"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "QuickLook's bar offers Done")
        done.tap()
        XCTAssertTrue(quickLook.waitForNonExistence(timeout: 5))
        XCTAssertTrue(cards.firstMatch.exists, "the chat is back")
    }

    /// Five pictures draw four tiles and "+1"; the last tile opens the fifth picture and the viewer pages back through
    /// all of them, stopping at the first.
    @MainActor
    func testOverflowTileOpensTheFifthPictureAndTheViewerPagesThroughAll() {
        openKickersRoomWithMockPicker()
        attachPhotosFromTheMockLibrary(5)
        let tiles = sendAndWaitForTiles(4)
        XCTAssertTrue(app.staticTexts["+1"].waitForExistence(timeout: 5), "the last tile counts the hidden picture")
        openTile(tiles.element(boundBy: 3))
        XCTAssertTrue(viewerShows("5 / 5"), "the +1 tile opens the fifth picture")
        XCTAssertTrue(viewerShows(["4 / 5", "3 / 5", "2 / 5", "1 / 5", "1 / 5"], swiping: .right), "the first stays")
        XCTAssertTrue(viewerShows(["2 / 5"], swiping: .left), "a swipe left pages forward again")
        let viewer = app.descendants(matching: .any)["attachment-viewer"]
        let middle = viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        middle.press(forDuration: 0.05,
                     thenDragTo: viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)),
                     withVelocity: .slow,
                     thenHoldForDuration: 0.5)
        XCTAssertTrue(viewerShows("2 / 5"), "a short drag down settles back on the same page, never turning it")
        middle.press(forDuration: 0.05,
                     thenDragTo: viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)),
                     withVelocity: .fast,
                     thenHoldForDuration: 0)
        XCTAssertTrue(viewer.waitForNonExistence(timeout: 5), "a drag down closes the viewer from any page")
    }

    /// A profile opened from a room stays in the room's flow: no tab bar, so the swipe back has nothing to hide.
    @MainActor
    func testAProfileOpenedFromARoomKeepsTheTabBarHidden() {
        tapSignInWithApple()
        openChatsTab()
        openRoom("group-row-mock-dm-mock-user-marta", titled: "Marta")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForNonExistence(timeout: 5), "a room hides the bar")

        app.buttons["chat-title"].tap()
        XCTAssertTrue(app.staticTexts["Groups in common"].waitForExistence(timeout: 10), "the profile opened")

        XCTAssertFalse(app.buttons["profile-message"].exists, "a profile reached from its chat offers no Message")
        XCTAssertFalse(app.tabBars.buttons["Home"].exists, "the profile pushed over the room keeps the bar away")
    }
}

/// The badge is read through the tab button's accessibility value (`AppBranding.Chats.unreadChats`): the badge itself
/// is not in the accessibility tree.
private extension LilyChatTests {
    /// Waits for the tab's value to read `expected`, naming what it read instead when it never does.
    @MainActor
    func expectBadge(of tab: XCUIElement, toRead expected: String) {
        let reads = expectation(for: NSPredicate(format: "value == %@", expected), evaluatedWith: tab)
        let outcome = XCTWaiter().wait(for: [reads], timeout: 10)
        XCTAssertEqual(outcome, .completed, "the Chats badge reads \(tab.value as? String ?? "nothing"), not \(expected)")
    }

    @MainActor
    func openRoomAndComeBack(_ rowID: String) {
        app.buttons[rowID].tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat-composer"].waitForExistence(timeout: 10), "the room opens")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout: 5), "back on the Chats root")
    }
}
