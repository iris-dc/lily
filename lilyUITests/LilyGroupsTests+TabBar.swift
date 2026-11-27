import XCTest

/// The tab bar over a chat opened in place from a group's detail. In an extension file so the test class stays under
/// the type-body limit, like the event and tournament classes.
extension LilyGroupsTests {
    /// A tab switch is no pop: with the chat open in place, leaving for Explore (⌘2 — the hidden bar offers no tap
    /// target) and coming back finds the chat still covering the bar; the detail hides the bar itself (2026-11-24),
    /// so only the pop to the stack's root brings it back.
    @MainActor
    func testTabSwitchKeepsTheBarHiddenOverTheChatOpenedInPlace() {
        tapSignInWithApple()
        openFromHome(app.buttons[MockIDs.kickersRow], segment: "Groups")
        let openChat = app.buttons["group-open-chat"]
        XCTAssertTrue(openChat.waitForExistence(timeout: 5), "a member may open the chat")
        openChat.tap()
        XCTAssertTrue(app.descendants(matching: .any)["chat-composer"].waitForExistence(timeout: 10), "the room opens")
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForNonExistence(timeout: 5),
                      "the chat pushed in place hides the bar")

        selectTabByShortcut(2, until: app.navigationBars["Explore"])
        let homeTab = app.tabBars.buttons["Home"]
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "Explore shows the bar")
        homeTab.tap()

        XCTAssertTrue(app.descendants(matching: .any)["chat-composer"].waitForExistence(timeout: 10),
                      "Home returns to the open chat")
        XCTAssertTrue(homeTab.waitForNonExistence(timeout: 5), "the tab switch freed no hide: the bar stays away")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["group-open-chat"].waitForExistence(timeout: 5), "Back returns to the detail")
        XCTAssertTrue(homeTab.waitForNonExistence(timeout: 5), "the detail hides the bar itself")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5), "Back again lands on Home's root")
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "the pop to the root frees every hide and the bar returns")
    }
}
