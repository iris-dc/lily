import XCTest

/// Polls and pins in Sunday Padel Crew's room, where the caller is the owner and the mock has a public poll by Marta
/// and a pin by Jonas; a test in an extension is discovered only when `@objc`.
extension LilyChatTests {
    /// A tap on an option votes and turns the options into results; View votes lists the caller under their pick.
    @objc @MainActor
    func testVotingInAPollShowsItsResultsAndVoters() {
        tapSignInWithApple()
        openRoom(MockIDs.padelRow, titled: "Sunday Padel Crew")
        let option = app.descendants(matching: .any)["poll-option-1"].firstMatch
        tapAfterScrolling(option)

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
        openRoom(MockIDs.padelRow, titled: "Sunday Padel Crew")
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
        openRoom(MockIDs.padelRow, titled: "Sunday Padel Crew")
        let bar = app.buttons["chat-pinned-bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "the room has a pin already")
        let line = app.staticTexts["Ha. See you Thursday."].firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        openContextMenu(on: line, until: app.buttons["message-pin"])
        app.buttons["message-pin"].tap()

        XCTAssertTrue(waitUntil(bar, holds: "label CONTAINS %@", "Ha. See you Thursday."), "the bar reads \(bar.label)")
        XCTAssertTrue(bar.label.contains("2 of 2"), "the newest of two pins shows")
        XCTAssertTrue(app.staticTexts["You pinned «Ha. See you Thursday.»"].waitForExistence(timeout: 5), "the note lands")

        app.buttons["chat-pinned-bar-unpin"].tap()
        XCTAssertTrue(waitUntil(bar, holds: "NOT (label CONTAINS %@)", "Ha. See you Thursday."),
                      "the bar still reads \(bar.label)")
    }

    /// A poll with several answers ticks its options and Vote sends them; the shares then show for every option.
    @objc @MainActor
    func testAMultipleAnswerPollTicksThenVotes() {
        tapSignInWithApple()
        openRoom(MockIDs.padelRow, titled: "Sunday Padel Crew")
        app.buttons["chat-attach"].tap()
        XCTAssertTrue(app.buttons["chat-attach-poll"].waitForExistence(timeout: 5))
        app.buttons["chat-attach-poll"].tap()
        enter("Which evenings?", into: app.textFields["poll-question"].firstMatch)
        enter("Tuesday", into: app.textFields["poll-option-field-0"])
        enter("Thursday", into: app.textFields["poll-option-field-1"])
        app.buttons["poll-add-option"].tap()
        enter("Friday", into: app.textFields["poll-option-field-2"])
        let multiple = app.switches["poll-multiple"].firstMatch
        XCTAssertTrue(multiple.waitForExistence(timeout: 5))
        // With the keyboard up the toggles sit under it; scrolled into the clear, a Toggle in a Form flips at its
        // trailing end (a tap in the middle lands on the label).
        scrollUntilHittable(multiple)
        multiple.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(waitUntil(multiple, holds: "value == '1'"), "the toggle reads \(String(describing: multiple.value))")
        app.buttons["poll-send"].tap()
        XCTAssertTrue(app.staticTexts["Which evenings?"].waitForExistence(timeout: 10), "the poll lands in the room")

        let vote = app.buttons.matching(identifier: "poll-vote").firstMatch
        XCTAssertTrue(vote.waitForExistence(timeout: 5))
        XCTAssertFalse(vote.isEnabled, "nothing ticked yet")
        let options = app.descendants(matching: .any).matching(identifier: "poll-option-0").allElementsBoundByIndex
        let seconds = app.descendants(matching: .any).matching(identifier: "poll-option-1").allElementsBoundByIndex
        options.last?.tap()
        seconds.last?.tap()
        XCTAssertTrue(vote.isEnabled, "two ticks make a vote")
        vote.tap()

        guard let total = app.staticTexts.matching(identifier: "poll-total").allElementsBoundByIndex.last else {
            return XCTFail("no poll total")
        }
        XCTAssertTrue(total.wait(for: \.label, toEqual: "1 vote", timeout: 5), "the total reads \(total.label), not 1 vote")
        XCTAssertTrue(vote.waitForNonExistence(timeout: 5), "Vote leaves once voted")
    }

    /// Retract vote in the long press takes the caller's vote back: the shares hide and View votes goes with them.
    @objc @MainActor
    func testRetractVoteFromTheLongPressHidesTheShares() {
        tapSignInWithApple()
        openRoom(MockIDs.padelRow, titled: "Sunday Padel Crew")
        let option = app.descendants(matching: .any)["poll-option-1"].firstMatch
        tapAfterScrolling(option)
        let voters = app.buttons["poll-voters"].firstMatch
        XCTAssertTrue(voters.waitForExistence(timeout: 5))

        let question = app.staticTexts["Which court for Sunday?"].firstMatch
        openContextMenu(on: question, until: app.buttons["message-retract-vote"])
        app.buttons["message-retract-vote"].tap()

        XCTAssertTrue(voters.waitForNonExistence(timeout: 5), "View votes goes once the vote is taken back")
        let total = app.staticTexts["poll-total"].firstMatch
        XCTAssertTrue(total.wait(for: \.label, toEqual: "3 votes", timeout: 5), "the total reads \(total.label), not 3 votes")
    }
}
