import XCTest

/// The sign-in sheet and the email form against the mock auth service.
final class LilySignInTests: LilyUITestCase {
    @MainActor
    func testMockAppleSignInFromSheetLandsInApp() {
        tapSignInWithApple()

        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testSignInFailureShowsThePopupAboveTheSheet() {
        relaunch(appending: "-mock-auth-fail")
        let apple = tapSignInWithApple()

        // The popup combines its children into one element, so match on the label.
        let popup = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "You're offline")).firstMatch
        XCTAssertTrue(popup.waitForExistence(timeout: 10), "a failed sign-in must show the shared error popup")
        waitUntilHittableAndStill(popup)
        XCTAssertTrue(popup.isHittable, "the popup must sit above the sheet, not behind it")
        XCTAssertTrue(apple.exists, "the sheet stays open after a failed sign-in")
    }

    @MainActor
    func testSignInFromProfileDismissesTheSheet() {
        relaunchAsGuest()
        app.tabBars.buttons["Profile"].tap()
        let apple = tapSignInWithApple()

        XCTAssertTrue(apple.waitForNonExistence(timeout: 10), "the sheet must close once the guest is signed in")
        XCTAssertTrue(app.staticTexts["Apple Tester"].waitForExistence(timeout: 5))
    }

    /// With `-mock-auth-confirm` the mock behaves like the pool: sign-up asks for the emailed code (123456 here), and
    /// confirming it signs the new user in. The step's fields, buttons and copy are what this walks through.
    @MainActor
    func testEmailSignUpConfirmsWithTheCodeAndLandsInApp() {
        relaunch(appending: "-mock-auth-confirm")
        openEmailForm()

        app.buttons["auth-mode-toggle"].tap()
        XCTAssertTrue(app.staticTexts["Create your account"].waitForExistence(timeout: 5))
        enter("jane.doe@example.com", into: app.textFields["auth-email"])
        enter("long-enough", into: app.secureTextFields["auth-password"])
        app.buttons["auth-submit"].tap()

        XCTAssertTrue(app.staticTexts["Check your email"].waitForExistence(timeout: 10), "sign-up must lead to the code step")
        XCTAssertTrue(app.staticTexts["We sent a code to jane.doe@example.com"].exists)
        XCTAssertTrue(app.buttons["auth-resend-code"].exists)
        XCTAssertTrue(app.buttons["auth-mode-toggle"].label == "Back to sign in")
        let code = app.textFields["auth-confirmation-code"]
        XCTAssertTrue(code.exists)
        XCTAssertFalse(app.buttons["auth-submit"].isEnabled, "Confirm waits for a complete code")
        attachScreenshot(named: "confirm-code")

        enter("123456", into: code)
        XCTAssertTrue(app.buttons["auth-submit"].isEnabled)
        app.buttons["auth-submit"].tap()

        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10), "a confirmed sign-up must sign the user in")
    }

    /// With `-mock-terms-pending` the mock account owes the current terms, so the sheet comes up as soon as the
    /// account loaded after the sign-in; it cannot be swiped away, and "I agree" (or "Sign out") is the only way on.
    /// The first gated write, a chat message, then goes through.
    @MainActor
    func testANewAccountAcceptsTheTermsBeforeItsFirstWrite() {
        relaunch(appending: "-mock-terms-pending")
        tapSignInWithApple()

        let accept = app.buttons["terms-accept"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10), "a new account is asked for the terms once its account loaded")
        XCTAssertTrue(app.staticTexts["Before you join in"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["terms-sign-out"].waitForExistence(timeout: 5),
                      "the only way out without agreeing is signing out")
        attachScreenshot(named: "terms-sheet")

        app.swipeDown()
        waitUntilHittableAndStill(accept)
        XCTAssertTrue(accept.isHittable, "the sheet cannot be swiped away")

        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 10), "the recorded acceptance closes the sheet")

        openChatsTab()
        let kickers = app.buttons["group-row-mock-group-kickers"]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        kickers.tap()
        XCTAssertTrue(app.navigationBars["Kreuzberg Kickers"].waitForExistence(timeout: 10), "a Chats row opens the room")

        let text = "See you at seven"
        enter(text, into: app.descendants(matching: .any)["chat-composer"])
        app.buttons["chat-send"].tap()
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10), "the write goes through once the terms are accepted")
    }
}
