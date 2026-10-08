import XCTest

/// The iPad layouts, run on an iPad simulator by `ci.sh ui-ipad`; the same launch as every other UI test class. On a
/// phone (the `ui` stage runs every class) the whole class is skipped: it asserts regular-width layouts.
final class LilyIPadTests: LilyUITestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "regular-width layouts need an iPad")
        // A rotation test that failed mid-way leaves the device in landscape; every case starts upright.
        XCUIDevice.shared.orientation = .portrait
        try super.setUpWithError()
    }

    @MainActor
    func testExploreShowsOnIPad() {
        relaunchAsGuest()
        // A grid on a regular width, a scroll view on a compact one: the identifier is the same either way.
        XCTAssertTrue(app.descendants(matching: .any)["group-carousel"].firstMatch.waitForExistence(timeout: 10),
                      "the group grid never appeared: \(app.debugDescription)")
    }

    /// Explore on a wide window: the map is a pane beside the content, the list/map picker is gone, and in landscape
    /// on the 13-inch two cards share a row of the grid. On a narrower iPad only the grid and the picker are asserted.
    @MainActor
    func testExploreShowsTwoCardsSideBySideAndTheMapPane() {
        relaunchAsGuest()
        XCUIDevice.shared.orientation = .landscapeLeft
        addTeardownBlock { XCUIDevice.shared.orientation = .portrait }
        // The card, not the map pin of the same title: only the card's label carries the place.
        let sunset = card(titled: "Sunset 5-a-side", at: "Riverside Pitch 2")
        let pickup = card(titled: "Pickup at the Cage", at: "Westside Courts")
        XCTAssertTrue(sunset.waitForExistence(timeout: 10) && pickup.waitForExistence(timeout: 10), app.debugDescription)
        // The rotation is asynchronous: the window turns first and the layout follows, so wait for both.
        waitForOrientation(landscape: true)
        waitUntilHittableAndStill(sunset)
        let width = app.windows.firstMatch.frame.width
        if width >= 1000 {
            XCTAssertTrue(app.otherElements["explore-map-pane"].waitForExistence(timeout: 5), "the map is a pane")
            XCTAssertFalse(app.segmentedControls["events-presentation"].exists, "no list/map switch beside a pane")
        } else {
            XCTAssertTrue(app.segmentedControls["events-presentation"].exists, "a narrower iPad keeps the switch")
        }
        // The column the cards get is what lies between the first card and the scroll view's right edge: in landscape
        // on the 13-inch that is two cards, on a narrower iPad one.
        let usable = app.scrollViews.firstMatch.frame.maxX - sunset.frame.minX
        if usable >= 2 * 340 + 16 {
            XCTAssertEqual(sunset.frame.minY, pickup.frame.minY, accuracy: 2, "two cards share a row")
            XCTAssertNotEqual(sunset.frame.minX, pickup.frame.minX, "side by side, not stacked")
        } else {
            XCTAssertGreaterThan(pickup.frame.minY, sunset.frame.maxY - 1, "one card per row in a narrow column")
            XCTAssertLessThanOrEqual(sunset.frame.width, 520, "a lone card stops at the grid's maximum")
        }
        XCUIDevice.shared.orientation = .portrait
        waitForOrientation(landscape: false)
        XCTAssertTrue(sunset.waitForExistence(timeout: 5))
        if width >= 1000 {
            XCTAssertTrue(app.otherElements["explore-map-pane"].waitForExistence(timeout: 5), "the pane survives a rotation")
        }
    }

    /// Polls the window until it is wider than tall (or the reverse), for up to five seconds.
    @MainActor
    private func waitForOrientation(landscape: Bool) {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let frame = app.windows.firstMatch.frame
            if (frame.width > frame.height) == landscape { return }
            usleep(200_000)
        }
        XCTFail("the window never turned to \(landscape ? "landscape" : "portrait")")
    }

    private func card(titled title: String, at place: String) -> XCUIElement {
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", title, place)).firstMatch
    }

    /// Discover's cards fill the width as a grid: the first two share a row.
    @MainActor
    func testDiscoverGroupsUsesAGrid() {
        relaunchAsGuest()
        let seeAll = app.buttons["groups-see-all"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 10))
        seeAll.tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'group-row-'"))
        XCTAssertTrue(rows.element(boundBy: 1).waitForExistence(timeout: 10), app.debugDescription)
        let first = rows.element(boundBy: 0), second = rows.element(boundBy: 1)
        XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 2, "two cards share a row")
        XCTAssertNotEqual(first.frame.minX, second.frame.minX)
    }

    /// On a regular width Chats is a split view: the list stays beside the room, through a rotation and back.
    @MainActor
    func testChatsSplitShowsListAndRoomTogether() {
        tapSignInWithApple()
        openChatsTab()
        let sidebar = app.otherElements["chats-sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.otherElements["chats-nothing-chosen"].waitForExistence(timeout: 5),
                      "nothing is chosen yet, so the detail says so")

        let kickers = app.buttons["group-row-mock-group-kickers"]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        kickers.tap()
        let composer = app.descendants(matching: .any)["chat-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 10), "the room opens in the detail column")
        XCTAssertTrue(sidebar.exists && kickers.exists, "the list stays beside the room")
        XCTAssertFalse(app.otherElements["chats-nothing-chosen"].exists)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(composer.waitForExistence(timeout: 5), "the room survives a rotation")
        XCTAssertTrue(kickers.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
    }

    /// The inbox is a conversation like the rooms: picked in the list, read in the detail column.
    @MainActor
    func testInboxOpensInTheDetailColumn() {
        tapSignInWithApple()
        openChatsTab()
        let inbox = app.buttons["inbox-row"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 10))
        inbox.tap()
        XCTAssertTrue(app.navigationBars["iskra"].waitForExistence(timeout: 10), "the inbox is titled after the app")
        let accept = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inbox-accept-'")).firstMatch
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "the inbox's cards are in the detail column")
        XCTAssertTrue(inbox.exists && app.buttons["group-row-mock-group-kickers"].exists, "the list stays beside it")
    }

    /// A sheet that is a form is a centred form sheet on an iPad, not a page as wide as the screen.
    @MainActor
    func testCreateSheetIsAFormOnIPad() {
        tapSignInWithApple()
        openExploreTab()
        tapCreateButton()
        let title = app.textFields["create-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), app.debugDescription)
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(title.frame.width, window.width - 200, "the field spans a form sheet, not the window")
        XCTAssertGreaterThan(title.frame.minX, 100, "the sheet is centred")
    }

    /// The landing on a regular width puts the miniature beside its caption: the headline starts well into the page
    /// (on a phone it starts at the margin).
    @MainActor
    func testLandingPlacesTheMiniatureBesideTheCopyOnIPad() {
        let headline = app.staticTexts["Play tonight."]
        XCTAssertTrue(headline.waitForExistence(timeout: 10))
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(headline.frame.minX, window.width * 0.3, "the caption sits right of the miniature")
        XCTAssertTrue(app.buttons["Find a game near you"].isHittable)
        XCTAssertLessThan(app.buttons["Find a game near you"].frame.width, window.width - 200, "the capsules are capped")
    }
}
