import XCTest

/// The Chats tab against the mock repositories: the pinned inbox row over the caller's rooms, the inbox itself with
/// Noor's invite into Climbing Buddies and the reminder for the first fixture game, deleting the conversation with
/// Marta from the room's menu, replying, and attaching a photo and a file through the mock picker. Identifiers mirror
/// `AccessibilityIdentifiers(+Inbox, +Attachments)`; the item ids mirror `MockInboxFixtures` (the tournament invite
/// and the match reminder, ids 1 and 3, are `LilyTournamentTests`').
final class LilyChatTests: LilyUITestCase {
    let inviteID = "01J8MOCKNB0000000000000004"
    let reminderID = "01J8MOCKNB0000000000000002"

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

    /// Deleting the conversation from the room's menu, after the confirmation: the chat closes, the Chats root no
    /// longer lists Marta, and the other rooms still open.
    @MainActor
    func testDeletingTheConversationWithMartaRemovesItFromChats() {
        tapSignInWithApple()
        openChatsTab()
        let marta = app.buttons["group-row-mock-dm-mock-user-marta"]
        XCTAssertTrue(marta.waitForExistence(timeout: 10))
        marta.tap()
        XCTAssertTrue(app.navigationBars["Marta"].waitForExistence(timeout: 10))

        let more = app.buttons["chat-more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let delete = app.buttons["chat-clear"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "the room's menu offers Delete chat")
        delete.tap()
        let confirmation = app.sheets.firstMatch
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
        openChatsTab()
        let kickers = app.buttons["group-row-mock-group-kickers"]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        kickers.tap()
        let original = "Anyone up for a game this week?"
        let line = app.staticTexts[original]
        XCTAssertTrue(line.waitForExistence(timeout: 10))
        // The room's first row: the transcript opens at the bottom, so bring it on screen before the long press, and
        // press again when the runner turned the press into a scroll (a CI runner did, 2026-10-09).
        var swipes = 0
        while !line.isHittable && swipes < 6 {
            app.swipeDown()
            swipes += 1
        }
        let reply = app.buttons["Reply"]
        var presses = 0
        while !reply.exists && presses < 3 {
            line.press(forDuration: 1.2)
            _ = reply.waitForExistence(timeout: 5)
            presses += 1
        }
        XCTAssertTrue(reply.exists, "the bubble's menu offers Reply")
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
        relaunch(appending: "-mock-attachment-picker")
        tapSignInWithApple()
        openChatsTab()
        let kickers = app.buttons["group-row-mock-group-kickers"]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        kickers.tap()
        XCTAssertTrue(app.navigationBars["Kreuzberg Kickers"].waitForExistence(timeout: 10))

        let attach = app.buttons["chat-attach"]
        XCTAssertTrue(attach.waitForExistence(timeout: 5), "the composer offers the attach menu")
        attach.tap()
        let library = app.buttons["Photo library"]
        XCTAssertTrue(library.waitForExistence(timeout: 5), "the menu offers the photo library")
        library.tap()

        let strip = app.descendants(matching: .any)["chat-attachment-strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10), "the picked photo shows above the field")
        let removes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chat-attachment-remove-'"))
        XCTAssertTrue(removes.firstMatch.waitForExistence(timeout: 5), "the tile carries its X")
        let send = app.buttons["chat-send"]
        XCTAssertTrue(send.wait(for: \.isEnabled, toEqual: true, timeout: 10), "Send opens once the upload is done")
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
        relaunch(appending: "-mock-attachment-picker")
        tapSignInWithApple()
        openChatsTab()
        let kickers = app.buttons["group-row-mock-group-kickers"]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        kickers.tap()
        XCTAssertTrue(app.navigationBars["Kreuzberg Kickers"].waitForExistence(timeout: 10))

        let attach = app.buttons["chat-attach"]
        XCTAssertTrue(attach.waitForExistence(timeout: 5))
        attach.tap()
        let file = app.buttons["File"]
        XCTAssertTrue(file.waitForExistence(timeout: 5), "the menu offers File")
        file.tap()

        let strip = app.descendants(matching: .any)["chat-attachment-strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10), "the picked file shows above the field")
        XCTAssertTrue(strip.staticTexts["training-plan.pdf"].waitForExistence(timeout: 5), "the chip names the file")
        let send = app.buttons["chat-send"]
        XCTAssertTrue(send.wait(for: \.isEnabled, toEqual: true, timeout: 10), "Send opens once the upload is done")
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
