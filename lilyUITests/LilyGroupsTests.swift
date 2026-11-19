import XCTest

/// Home, the groups on Explore and the rooms on Chats against the mock repositories: your groups on Home, the carousel
/// and Discover on Explore, joining, creating, games hosted in a group, and the chat. Identifiers mirror
/// `AccessibilityIdentifiers(+Groups)`; the mock ids mirror `MockGroupFixtures`.
final class LilyGroupsTests: LilyUITestCase {
    /// Home's Groups segment lists the caller's communities with the count line; the default Events segment lists
    /// their joined games. One segment shows at a time: each list's rows leave with its segment.
    @MainActor
    func testHomeListsMockGroupsAndGames() {
        tapSignInWithApple()
        openHomeTab()
        selectHomeSegment("Groups")

        XCTAssertTrue(app.buttons[MockIDs.kickersRow].waitForExistence(timeout: 10))
        XCTAssertTrue(labelled("Kreuzberg Kickers").exists)
        XCTAssertTrue(labelled("Tempelhof Runners").exists)
        XCTAssertTrue(labelled("Sunday Padel Crew").exists)
        XCTAssertFalse(app.buttons[MockIDs.basketballRow].exists, "Home lists the caller's groups only")
        XCTAssertTrue(app.staticTexts["3 groups"].waitForExistence(timeout: 5), "the count line sums the caller's groups")
        XCTAssertTrue(app.staticTexts["Sunset 5-a-side"].waitForNonExistence(timeout: 5),
                      "the Groups segment shows no event card")

        selectHomeSegment("Events")
        XCTAssertTrue(app.staticTexts["Sunset 5-a-side"].waitForExistence(timeout: 10),
                      "the Events segment lists the caller's games")
        XCTAssertTrue(app.buttons[MockIDs.kickersRow].waitForNonExistence(timeout: 5),
                      "the group rows leave with their segment")
    }

    @MainActor
    func testGuestHomeOffersSignIn() {
        relaunchAsGuest()
        openHomeTab()

        XCTAssertTrue(app.staticTexts["You're browsing as a guest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign in"].exists)
        XCTAssertFalse(app.buttons[MockIDs.kickersRow].exists)
    }

    /// The carousel on Explore lists the public groups; "See all" leads to Discover, which searches by name prefix.
    @MainActor
    func testExploreCarouselLeadsToDiscoverWhoseSearchFindsBerlinBasketball() {
        relaunchAsGuest()
        XCTAssertTrue(app.buttons[MockIDs.kickersRow].waitForExistence(timeout: 10),
                      "the carousel shows public groups to a guest")
        showDiscover()
        XCTAssertTrue(app.buttons[MockIDs.kickersRow].waitForExistence(timeout: 10))

        enter("Berlin", into: app.searchFields.firstMatch)

        XCTAssertTrue(app.buttons[MockIDs.kickersRow].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons[MockIDs.basketballRow].waitForExistence(timeout: 10))
    }

    @MainActor
    func testJoinPublicGroupFromDiscoverShowsOnHome() {
        tapSignInWithApple()
        showDiscover()
        tapAfterScrolling(app.buttons[MockIDs.basketballRow])

        let join = app.buttons["group-join"]
        XCTAssertTrue(join.waitForExistence(timeout: 5))
        join.tap()
        let openChat = app.buttons["group-open-chat"]
        XCTAssertTrue(openChat.waitForExistence(timeout: 10), "a join must turn the actions into a member's")

        openHomeTab()
        selectHomeSegment("Groups")
        XCTAssertTrue(app.buttons[MockIDs.basketballRow].waitForExistence(timeout: 10), "the joined group must be listed on Home")
    }

    /// A game created from a group's detail lands straight on its own detail, hosted in the group (the owner's
    /// fourth round); behind it the group's Events segment lists it and, being a public group's game, the Explore
    /// list carries its card with the group's badge, without a manual refresh.
    @MainActor
    func testGroupEventCreatedFromGroupShowsBadgeOnExplore() {
        tapSignInWithApple()
        openKickersDetail()
        let title = "Kickers Friday night"
        createGame(titled: title)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), "the create must land on the new game's detail")
        XCTAssertTrue(app.staticTexts["Hosted in Kreuzberg Kickers"].waitForExistence(timeout: 5),
                      "the detail must name the hosting group")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5), "the detail was pushed on Home")

        selectTab("Explore")
        XCTAssertTrue(labelled(title).waitForExistence(timeout: 10), "the group's Events segment must list the new game")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        let created = card(containing: title)
        scrollUntilHittable(created)
        XCTAssertTrue(created.label.contains("Kreuzberg Kickers"), "the card must carry the group badge: \(created.label)")

        created.tap()
        XCTAssertTrue(app.staticTexts["Hosted in Kreuzberg Kickers"].waitForExistence(timeout: 5))
    }

    /// From a group the wizard opens seeded, straight on Name, and the walk has no Hosting group step (the group is
    /// locked); a dirty Cancel asks to discard.
    @MainActor
    func testCreatingAnEventInsideAGroupSkipsTheGroupStep() {
        tapSignInWithApple()
        openKickersDetail()
        app.buttons["group-create-event"].tap()
        waitForWizardStep("Name")

        enter("Locked walk", into: app.textFields["create-title"])
        tapNext()
        pickWizardEventType()
        waitForWizardStep("When")
        tapNext()
        waitForWizardStep("Place")
        XCTAssertFalse(app.navigationBars["Hosting group"].exists, "the locked group leaves no group step")
        app.buttons["create-cancel"].tap()
        confirm("Discard")
        XCTAssertTrue(app.navigationBars["Place"].waitForNonExistence(timeout: 5),
                      "a dirty wizard closes on the confirmed discard")
    }

    /// From Explore the "+" menu's "New event" opens the wizard on Name; a clean Cancel there closes silently, and
    /// the wizard gives the choice its own Hosting group step starting at "No group". A dirty Cancel asks to discard.
    @MainActor
    func testCreatingFromExploreOffersTheGroupChoice() {
        tapSignInWithApple()
        tapCreateMenuItem("New event")
        waitForWizardStep("Name")
        app.buttons["create-cancel"].tap()
        XCTAssertTrue(app.navigationBars["Name"].waitForNonExistence(timeout: 5), "a clean wizard closes silently")

        tapCreateMenuItem("New event")
        waitForWizardStep("Name")
        enter("Group pick", into: app.textFields["create-title"])
        tapNext()
        pickWizardEventType()
        waitForWizardStep("When")
        tapNext()
        waitForWizardStep("Hosting group")
        let picker = app.descendants(matching: .any)["create-group"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "a member of groups gets the choice on its own step")
        XCTAssertTrue(text(of: picker).contains("No group"), "nothing is preselected from Explore: \(text(of: picker))")
        XCTAssertTrue(app.staticTexts["A group event lives on that group's page. Without one it's open to everyone."]
            .exists, "the step explains what the choice means")
        app.buttons["create-cancel"].tap()
        confirm("Discard")
        XCTAssertTrue(app.navigationBars["Hosting group"].waitForNonExistence(timeout: 5),
                      "a dirty wizard closes on the confirmed discard")
    }

    /// Inviting starts on the group's detail, reached from Home: the sheet lists the people the caller shares a group
    /// or a game with, the search narrows them by name, and a sent invite turns its button into "Invited".
    @MainActor
    func testInvitingAPersonFromTheGroupMarksThemInvited() {
        tapSignInWithApple()
        openHomeTab()
        selectHomeSegment("Groups")
        let padel = app.buttons[MockIDs.padelRow]
        XCTAssertTrue(padel.waitForExistence(timeout: 10))
        padel.tap()
        let invite = app.buttons["group-invite"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5), "the owner may invite")
        invite.tap()
        XCTAssertTrue(app.navigationBars["Invite people"].waitForExistence(timeout: 5))

        let send = app.buttons["invite-send-mock-user-marta"]
        XCTAssertTrue(send.waitForExistence(timeout: 10), "Marta, from Kreuzberg Kickers, is a candidate")
        XCTAssertTrue(labelled("In Kreuzberg Kickers").exists)
        enter("Mar", into: app.textFields["invite-search"])
        XCTAssertTrue(app.buttons["invite-send-mock-user-aiko"].waitForNonExistence(timeout: 5), "the search narrows the list")
        send.tap()

        let sent = app.buttons.matching(identifier: "invite-send-mock-user-marta")
            .matching(NSPredicate(format: "label == %@", "Invited")).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 10), "a sent invite reads Invited")
        XCTAssertFalse(sent.isEnabled)
    }

    /// A message typed into the composer shows as the caller's bubble; the text is asserted because the bubble's
    /// identifier is the client id chosen for that send.
    @MainActor
    func testOpenChatSendShowsOwnBubble() {
        tapSignInWithApple()
        openRoom(MockIDs.kickersRow, titled: "Kreuzberg Kickers")
        XCTAssertTrue(app.staticTexts["Anyone up for a game this week?"].waitForExistence(timeout: 10),
                      "the fixture history shows")

        let text = "See you at seven"
        let composer = app.descendants(matching: .any)["chat-composer"]
        enter(text, into: composer)
        let send = app.buttons["chat-send"]
        assertBecomesEnabled(send, "text enables Send")
        send.tap()

        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10), "the sent message shows as a bubble")
        // An empty field reports its placeholder as its value.
        XCTAssertEqual(composer.value as? String, "Message", "the composer is empty again")
    }

    /// Kreuzberg Kickers has unread messages in the fixtures: its Chats row carries the dot until the room has been
    /// opened. The tab badge that goes with it is not exposed to XCUITest by the iOS 26 tab bar (no value, no child),
    /// so it is checked by screenshot instead.
    @MainActor
    func testUnreadRoomShowsDotUntilOpened() {
        tapSignInWithApple()
        let kickers = chatsRow(MockIDs.kickersRow)
        let dot = kickers.descendants(matching: .any)["Unread messages"]
        XCTAssertTrue(dot.waitForExistence(timeout: 10), "the unread row carries the dot")
        kickers.tap()
        XCTAssertTrue(app.navigationBars["Kreuzberg Kickers"].waitForExistence(timeout: 10))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Chats"].waitForExistence(timeout: 5))
        XCTAssertTrue(kickers.waitForExistence(timeout: 5))
        XCTAssertFalse(dot.exists, "reading the room clears the dot")
    }

    /// "Open chat" on a group's detail opens the room in place, on the same stack, so Back returns to the detail
    /// rather than to the Chats root; the room hides the tab bar, Back restores it, and the Chats tab still lists
    /// the room.
    @MainActor
    func testOpenChatFromGroupDetailComesBackToTheDetail() {
        tapSignInWithApple()
        openFromHome(app.buttons[MockIDs.kickersRow], segment: "Groups")
        let openChat = app.buttons["group-open-chat"]
        XCTAssertTrue(openChat.waitForExistence(timeout: 5), "a member may open the chat")
        openChat.tap()

        XCTAssertTrue(app.descendants(matching: .any)["chat-composer"].waitForExistence(timeout: 10), "the room opens")
        XCTAssertTrue(app.navigationBars["Kreuzberg Kickers"].exists, "the room is titled with the group")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForNonExistence(timeout: 5), "the chat pushed in place hides the bar")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(openChat.waitForExistence(timeout: 5), "Back returns to the group's detail, not the Chats root")
        XCTAssertTrue(labelled("Kreuzberg Kickers").exists, "the header still names the group")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5), "the bar returns with the detail")

        chatsRow(MockIDs.kickersRow)
    }
}
