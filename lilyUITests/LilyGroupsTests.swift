import XCTest

/// Home and the groups on Explore against the mock repositories: your groups on Home, the carousel and Discover on
/// Explore, joining, creating, invite codes, and games hosted in a group. Identifiers mirror
/// `AccessibilityIdentifiers(+Groups)`; the mock ids mirror `MockGroupFixtures`.
final class LilyGroupsTests: LilyUITestCase {
    let kickersRow = "group-row-mock-group-kickers"
    let basketballRow = "group-row-mock-group-basketball"
    /// `AppConfig.Groups.mockInviteCode`: previews and admits into Climbing Buddies.
    let mockInviteCode = "KRZB7K3MQX9P"

    @MainActor
    func testHomeListsMockGroupsAndGames() {
        tapSignInWithApple()
        openHomeTab()

        XCTAssertTrue(app.buttons[kickersRow].waitForExistence(timeout: 10))
        XCTAssertTrue(labelled("Kreuzberg Kickers").exists)
        XCTAssertTrue(labelled("Tempelhof Runners").exists)
        XCTAssertTrue(labelled("Sunday Padel Crew").exists)
        XCTAssertFalse(app.buttons[basketballRow].exists, "Home lists the caller's groups only")
        XCTAssertTrue(app.staticTexts["Your games"].waitForExistence(timeout: 5), "the caller's games follow their groups")
    }

    @MainActor
    func testGuestHomeOffersSignIn() {
        relaunchAsGuest()
        openHomeTab()

        XCTAssertTrue(app.staticTexts["You're browsing as a guest"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Sign in"].exists)
        XCTAssertFalse(app.buttons[kickersRow].exists)
    }

    /// The carousel on Explore lists the public groups; "See all" leads to Discover, which searches by name prefix.
    @MainActor
    func testExploreCarouselLeadsToDiscoverWhoseSearchFindsBerlinBasketball() {
        relaunchAsGuest()
        XCTAssertTrue(app.buttons[kickersRow].waitForExistence(timeout: 10), "the carousel shows public groups to a guest")
        showDiscover()
        XCTAssertTrue(app.buttons[kickersRow].waitForExistence(timeout: 10))

        enter("Berlin", into: app.searchFields.firstMatch)

        XCTAssertTrue(app.buttons[kickersRow].waitForNonExistence(timeout: 10))
        XCTAssertTrue(app.buttons[basketballRow].waitForExistence(timeout: 10))
    }

    @MainActor
    func testJoinPublicGroupFromDiscoverShowsOnHome() {
        tapSignInWithApple()
        showDiscover()
        let basketball = app.buttons[basketballRow]
        XCTAssertTrue(basketball.waitForExistence(timeout: 10))
        scrollUntilHittable(basketball)
        basketball.tap()

        let join = app.buttons["group-join"]
        XCTAssertTrue(join.waitForExistence(timeout: 5))
        join.tap()
        let openChat = app.buttons["group-open-chat"]
        XCTAssertTrue(openChat.waitForExistence(timeout: 10), "a join must turn the actions into a member's")

        openHomeTab()
        XCTAssertTrue(app.buttons[basketballRow].waitForExistence(timeout: 10), "the joined group must be listed on Home")
    }

    /// Groups are founded from the "+" on Explore; the founder lands in the new group, and Home lists it.
    @MainActor
    func testCreateGroupFromExploreShowsOnHome() {
        tapSignInWithApple()
        tapCreateMenuItem("New group")
        XCTAssertTrue(app.navigationBars["New group"].waitForExistence(timeout: 5))

        let name = "Thursday Runners"
        enter(name, into: app.textFields["create-group-name"])
        let submit = app.buttons["create-group-submit"]
        XCTAssertTrue(submit.isEnabled, "a name completes the draft")
        submit.tap()

        XCTAssertTrue(app.navigationBars["New group"].waitForNonExistence(timeout: 10), "the sheet must close once created")
        XCTAssertTrue(app.buttons["group-open-chat"].waitForExistence(timeout: 10), "the founder must land in the new group")
        XCTAssertTrue(labelled(name).exists, "the detail must be the new group's")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(labelled(name).waitForExistence(timeout: 10), "the new group must be listed on Home")
    }

    @MainActor
    func testJoinWithMockInviteCodeOpensClimbingBuddies() {
        tapSignInWithApple()
        openHomeTab()
        let joinWithCode = app.buttons["groups-join-code"]
        XCTAssertTrue(joinWithCode.waitForExistence(timeout: 10))
        joinWithCode.tap()

        enter(mockInviteCode, into: app.textFields["invite-code-field"])
        let proceed = app.buttons["invite-continue"]
        XCTAssertTrue(proceed.isEnabled, "a complete code enables Continue")
        proceed.tap()

        let redeem = app.buttons["invite-redeem"]
        XCTAssertTrue(redeem.waitForExistence(timeout: 10))
        XCTAssertTrue(labelled("Climbing Buddies").exists, "the preview names the group")
        redeem.tap()
        let chat = app.navigationBars["Climbing Buddies"]
        XCTAssertTrue(chat.waitForExistence(timeout: 10), "redeeming must open the group's chat")
    }

    /// The launch argument stands in for a tapped invite link: the preview opens over the app, a guest signs in on
    /// Join, and the join continues into the chat.
    @MainActor
    func testOpenInviteArgumentShowsPreview() {
        relaunch(appendingArguments: ["-start-as-guest", "-open-invite", mockInviteCode])

        XCTAssertTrue(app.staticTexts["You're invited"].waitForExistence(timeout: 10))
        XCTAssertTrue(labelled("Climbing Buddies").exists)
        let redeem = app.buttons["invite-redeem"]
        XCTAssertTrue(redeem.waitForExistence(timeout: 5))
        redeem.tap()

        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5), "a guest must sign in before joining")
        apple.tap()
        XCTAssertTrue(app.navigationBars["Climbing Buddies"].waitForExistence(timeout: 15), "the join continues into the chat")
    }

    /// A game created from a group's detail lands in its Events segment and, being a public group's game, in the
    /// Explore list behind it with the group's badge on its card, without a manual refresh.
    @MainActor
    func testGroupEventCreatedFromGroupShowsBadgeOnExplore() {
        tapSignInWithApple()
        openKickersDetail()
        let title = "Kickers Friday night"
        createGame(titled: title)
        XCTAssertTrue(labelled(title).waitForExistence(timeout: 10), "the group's Events segment must list the new game")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        let card = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        scrollUntilHittable(card)
        XCTAssertTrue(card.label.contains("Kreuzberg Kickers"), "the card must carry the group badge: \(card.label)")

        card.tap()
        XCTAssertTrue(app.staticTexts["Hosted in Kreuzberg Kickers"].waitForExistence(timeout: 5))
    }

    /// From a group the form shows the group read-only; from Explore it offers a choice starting at "No group".
    @MainActor
    func testCreatingAnEventInsideAGroupPresetsTheGroup() {
        tapSignInWithApple()
        openKickersDetail()
        app.buttons["group-create-event"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 5))

        let locked = app.descendants(matching: .any)["create-group"]
        XCTAssertTrue(locked.waitForExistence(timeout: 5))
        XCTAssertTrue(text(of: locked).contains("Kreuzberg Kickers"), "the group must be preset: \(text(of: locked))")
        app.buttons["create-cancel"].tap()
        XCTAssertTrue(app.navigationBars["New game"].waitForNonExistence(timeout: 5))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        tapCreateButton()
        XCTAssertTrue(app.navigationBars["New game"].waitForExistence(timeout: 5))
        let picker = app.descendants(matching: .any)["create-group"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "a member of groups gets the Group row")
        XCTAssertTrue(text(of: picker).contains("No group"), "nothing is preselected from Explore: \(text(of: picker))")
    }

    /// A message typed into the composer shows as the caller's bubble; the text is asserted because the bubble's
    /// identifier is the client id chosen for that send.
    @MainActor
    func testOpenChatSendShowsOwnBubble() {
        tapSignInWithApple()
        openHomeTab()
        let kickers = app.buttons[kickersRow]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        kickers.tap()
        XCTAssertTrue(app.navigationBars["Kreuzberg Kickers"].waitForExistence(timeout: 10), "a Home row opens the chat")
        XCTAssertTrue(app.staticTexts["Anyone up for a game this week?"].waitForExistence(timeout: 10),
                      "the fixture history shows")

        let text = "See you at seven"
        let composer = app.descendants(matching: .any)["chat-composer"]
        enter(text, into: composer)
        let send = app.buttons["chat-send"]
        XCTAssertTrue(send.isEnabled, "text enables Send")
        send.tap()

        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10), "the sent message shows as a bubble")
        // An empty field reports its placeholder as its value.
        XCTAssertEqual(composer.value as? String, "Message", "the composer is empty again")
    }

    /// Kreuzberg Kickers has unread messages in the fixtures: its Home row carries the dot until the room has been
    /// opened. The tab badge that goes with it is not exposed to XCUITest by the iOS 26 tab bar (no value, no child),
    /// so it is checked by screenshot instead.
    @MainActor
    func testUnreadRoomShowsDotUntilOpened() {
        tapSignInWithApple()
        openHomeTab()
        let kickers = app.buttons[kickersRow]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        let dot = kickers.descendants(matching: .any)["Unread messages"]
        XCTAssertTrue(dot.waitForExistence(timeout: 10), "the unread row carries the dot")
        kickers.tap()
        XCTAssertTrue(app.navigationBars["Kreuzberg Kickers"].waitForExistence(timeout: 10))

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(kickers.waitForExistence(timeout: 5))
        XCTAssertFalse(dot.exists, "reading the room clears the dot")
    }
}
