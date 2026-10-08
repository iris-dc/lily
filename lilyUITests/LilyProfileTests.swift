import XCTest

/// The contact form on Profile: a guest is sent to sign in first, a user picks what the message is about, writes it
/// and is thanked; the mock accepts the send, so no backend is needed.
final class LilyProfileTests: LilyUITestCase {
    @MainActor
    func testSendingFeedbackFromProfileThanksTheUser() {
        relaunchAsGuest()
        openProfileTab()

        let row = app.buttons["profile-feedback"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5), "a guest is offered to sign in first")
        apple.tap()
        XCTAssertTrue(app.buttons["Sign out"].waitForExistence(timeout: 10))

        row.tap()
        XCTAssertTrue(app.navigationBars["Contact us"].waitForExistence(timeout: 5))
        let send = app.buttons["feedback-submit"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        XCTAssertFalse(send.isEnabled, "nothing goes out without a message")
        let email = app.textFields["feedback-email"].value as? String ?? ""
        XCTAssertTrue(email.contains("@"), "the email starts as the account's, not as the placeholder")

        app.buttons["Bug"].tap()
        enter("The map shows no pins after I change the radius.", into: app.descendants(matching: .any)["feedback-message"])
        XCTAssertTrue(send.wait(for: \.isEnabled, toEqual: true, timeout: 5))
        send.tap()

        XCTAssertTrue(app.staticTexts["Thanks for writing"].waitForExistence(timeout: 5))
        app.buttons["feedback-done"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
    }
}
