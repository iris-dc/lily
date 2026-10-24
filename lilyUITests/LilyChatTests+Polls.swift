import XCTest

/// Polls and pins in Sunday Padel Crew's room, where the caller is the owner and the mock has a public poll by Marta
/// and a pin by Jonas; a test in an extension is discovered only when `@objc`.
extension LilyChatTests {
    private var padelRow: String { "group-row-mock-group-padel" }

    /// A tap on an option votes and turns the options into results; View votes lists the caller under their pick.
    @objc @MainActor
    func testVotingInAPollShowsItsResultsAndVoters() {
        tapSignInWithApple()
        openChatsTab()
        openRoom(padelRow, titled: "Sunday Padel Crew")
        let option = app.descendants(matching: .any)["poll-option-1"].firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        scrollUntilHittable(option)
        option.tap()

        let total = app.staticTexts["poll-total"].firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "4 votes", "the caller counts as the fourth voter")
        let voters = app.buttons["poll-voters"].firstMatch
        XCTAssertTrue(voters.waitForExistence(timeout: 5), "a public poll offers its voters once voted")
        voters.tap()
        XCTAssertTrue(app.staticTexts["You"].waitForExistence(timeout: 5), "the caller is listed under their pick")
        app.buttons["Done"].tap()
    }

    /// The "+" menu's Poll opens the sheet; Send posts the poll into the room.
    @objc @MainActor
    func testAPollIsCreatedFromThePlusMenu() {
        tapSignInWithApple()
        openChatsTab()
        openRoom(padelRow, titled: "Sunday Padel Crew")
        let attach = app.buttons["chat-attach"]
        XCTAssertTrue(attach.waitForExistence(timeout: 10))
        attach.tap()
        let pollItem = app.buttons["chat-attach-poll"]
        XCTAssertTrue(pollItem.waitForExistence(timeout: 5))
        pollItem.tap()

        enter("Bring snacks?", into: app.textFields["poll-question"].firstMatch)
        enter("Yes", into: app.textFields["poll-option-field-0"])
        enter("No", into: app.textFields["poll-option-field-1"])
        let send = app.buttons["poll-send"]
        XCTAssertTrue(send.isEnabled, "two options and a question make a poll")
        send.tap()

        XCTAssertTrue(app.staticTexts["Bring snacks?"].waitForExistence(timeout: 10), "the poll lands in the room")
    }

    /// Pinning from the long press shows the message in the bar and posts the note; the bar's ✕ unpins it again.
    @objc @MainActor
    func testPinningAMessageShowsItInTheBarAndTheBarUnpinsIt() {
        tapSignInWithApple()
        openChatsTab()
        openRoom(padelRow, titled: "Sunday Padel Crew")
        let bar = app.buttons["chat-pinned-bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "the room has a pin already")
        let line = app.staticTexts["Ha. See you Thursday."].firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        openContextMenu(on: line, until: app.buttons["message-pin"])
        app.buttons["message-pin"].tap()

        let pinned = NSPredicate(format: "label CONTAINS %@", "Ha. See you Thursday.")
        expectation(for: pinned, evaluatedWith: bar)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(bar.label.contains("2 of 2"), "the newest of two pins shows")
        XCTAssertTrue(app.staticTexts["You pinned «Ha. See you Thursday.»"].waitForExistence(timeout: 5), "the note lands")

        app.buttons["chat-pinned-bar-unpin"].tap()
        let earlier = NSPredicate(format: "NOT (label CONTAINS %@)", "Ha. See you Thursday.")
        expectation(for: earlier, evaluatedWith: bar)
        waitForExpectations(timeout: 5)
    }
}
