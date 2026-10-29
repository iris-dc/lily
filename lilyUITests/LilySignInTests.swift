import XCTest

/// The sign-in sheet and the email form against the mock auth service.
final class LilySignInTests: LilyUITestCase {
    @MainActor
    func testMockAppleSignInFromSheetLandsInApp() {
        tapSignInWithApple()

        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
    }

    /// The popup is held open for the run: it fades after four seconds on its own, which on the runner was before the
    /// test had looked.
    @MainActor
    func testSignInFailureShowsThePopupAboveTheSheet() {
        relaunch(appendingArguments: ["-mock-auth-fail", "-hold-popups"])
        let apple = tapSignInWithApple()

        // The popup combines its children into one element, so match on the label.
        let popup = labelled("You're offline")
        XCTAssertTrue(popup.waitForExistence(timeout: 10), "a failed sign-in must show the shared error popup")
        waitUntilHittableAndStill(popup)
        XCTAssertTrue(popup.isHittable, "the popup must sit above the sheet, not behind it")
        XCTAssertTrue(apple.exists, "the sheet stays open after a failed sign-in")
    }

    @MainActor
    func testSignInFromProfileDismissesTheSheet() {
        relaunchAsGuest()
        openProfileTab()
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
        enter("long-enough", into: passwordField())
        app.buttons["auth-submit"].tap()

        XCTAssertTrue(app.staticTexts["Check your email"].waitForExistence(timeout: 10), "sign-up must lead to the code step")
        XCTAssertTrue(app.staticTexts["We sent a code to jane.doe@example.com"].exists)
        XCTAssertTrue(app.buttons["auth-resend-code"].exists)
        XCTAssertEqual(app.buttons["auth-mode-toggle"].label, "Back to sign in")
        let code = app.textFields["auth-confirmation-code"]
        XCTAssertTrue(code.exists)
        XCTAssertFalse(app.buttons["auth-submit"].isEnabled, "Confirm waits for a complete code")
        attachScreenshot(named: "confirm-code")

        enter("123456", into: code)
        assertBecomesEnabled(app.buttons["auth-submit"], "a complete code enables Confirm")
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

        openRoom("group-row-mock-group-kickers", titled: "Kreuzberg Kickers")

        let text = "See you at seven"
        enter(text, into: app.descendants(matching: .any)["chat-composer"])
        app.buttons["chat-send"].tap()
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 10), "the write goes through once the terms are accepted")
    }
}

/// The sheet's layout: a bar with Close over the title, the email form's title where the sheet's is, and the landing left
/// as it was once the sheet goes.
extension LilySignInTests {
    @objc @MainActor
    func testTheCloseButtonDismissesTheSheet() {
        openSignInSheet()
        let close = app.buttons["sign-in-close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "the sheet's bar carries Close")
        close.tap()
        XCTAssertTrue(app.buttons["Continue with Apple"].waitForNonExistence(timeout: 5), "Close takes the sheet away")
        XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 5), "the landing is back")
    }

    /// The form's title sits where the sheet's did, and stays there: with the bar on the form alone it sat a bar lower
    /// and dropped another 16 pt half a second after the push.
    @objc @MainActor
    func testTheEmailFormKeepsTheTitleWhereTheSheetHadIt() {
        openSignInSheet()
        let sheetSubtitle = app.staticTexts["Sign in to create events, join and chat."]
        XCTAssertTrue(sheetSubtitle.waitForExistence(timeout: 5))
        let sheetY = sheetSubtitle.frame.minY
        app.buttons["Continue with Email"].tap()
        let formSubtitle = app.staticTexts["Use your email and a password."]
        XCTAssertTrue(formSubtitle.waitForExistence(timeout: 5))
        let pushedY = formSubtitle.frame.minY
        sleep(1)
        XCTAssertEqual(pushedY, sheetY, accuracy: 1, "the form's title block starts where the sheet's did")
        XCTAssertEqual(formSubtitle.frame.minY, pushedY, accuracy: 0.5, "nothing moves after the push")
    }

    /// Back from the form with the keyboard up, the providers sit where they sat before: the keyboard pushes the sheet
    /// up and extends it to the screen's bottom behind it, and buttons centred in that height used to jump to their
    /// places when the keyboard went.
    @objc @MainActor
    func testTheProvidersKeepTheirPlacesAfterTheKeyboardAndTheWayBack() {
        openSignInSheet()
        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        let restY = apple.frame.minY
        app.buttons["Continue with Email"].tap()
        let email = app.textFields["auth-email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the field brings the keyboard")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(apple.waitForExistence(timeout: 5), "back to the providers")
        sleep(1)
        XCTAssertEqual(apple.frame.minY, restY, accuracy: 1, "the buttons are where they were, with nothing to jump to")
    }

    /// The sheet's keyboard is the window's: it used to shrink the landing's pages under the sheet, and the pager came
    /// back caught between two slides once the sheet was swiped away with the keyboard up.
    @objc @MainActor
    func testTheLandingKeepsItsSlideAfterTheKeyboardAndTheSheetsDismissal() {
        let pager = app.scrollViews["intro-pager"]
        XCTAssertTrue(pager.waitForExistence(timeout: 5))
        pager.swipeUp()
        let headline = app.staticTexts["Join a group"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5), "the second slide is up")
        sleep(1)
        let before = headline.frame
        openEmailForm()
        app.textFields["auth-email"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "the field brings the keyboard")
        let grabber = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
        let bottom = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        grabber.press(forDuration: 0.1, thenDragTo: bottom, withVelocity: .default, thenHoldForDuration: 0)
        XCTAssertTrue(app.textFields["auth-email"].waitForNonExistence(timeout: 5), "the swipe takes the sheet away")
        sleep(1)
        XCTAssertTrue(headline.exists, "the landing shows the slide it showed before")
        XCTAssertEqual(headline.frame.minY, before.minY, accuracy: 1, "the slide sits where it sat, not between pages")
    }

    /// The focus moving between the fields moves the sheet once each way: the password field's keyboard carries the
    /// Passwords bar, the email field's does not, and the sheet follows the keyboard. The title's rows are sampled
    /// through each move and may never turn back; with a secure field beside the email field at the moment the latter
    /// takes the focus, the sheet dipped about 18 pt and eased back on every change.
    @MainActor
    func testTheTitleMovesOnceWhenTheFocusChangesField() {
        openEmailForm()
        let title = app.staticTexts["Welcome back"]
        let email = app.textFields["auth-email"]
        email.tap()
        XCTAssertTrue(waitForKeyboardFocus(email))
        sleep(1)
        let withEmail = title.frame.minY

        let password = passwordField()
        XCTAssertTrue(waitForKeyboardFocus(password))
        let rise = sampleTitleRows(title)
        XCTAssertTrue(isMonotonic(rise, rising: true), "the sheet must rise once for the password field: \(rise)")
        XCTAssertLessThan(rise.last ?? withEmail, withEmail - 20, "the password field's taller keyboard lifts the sheet")

        email.tap()
        XCTAssertTrue(waitForKeyboardFocus(email))
        let fall = sampleTitleRows(title)
        XCTAssertTrue(isMonotonic(fall, rising: false), "the sheet must come down once for the email field: \(fall)")
        XCTAssertEqual(fall.last ?? 0, withEmail, accuracy: 1, "the email field's keyboard puts the sheet back")
    }

    /// The title's top edge about every 50 ms for a second, from the first sample on.
    @MainActor
    private func sampleTitleRows(_ title: XCUIElement) -> [CGFloat] {
        let deadline = Date().addingTimeInterval(1)
        var rows: [CGFloat] = []
        while Date() < deadline {
            rows.append(title.frame.minY)
            usleep(50_000)
        }
        return rows
    }

    private func isMonotonic(_ rows: [CGFloat], rising: Bool) -> Bool {
        zip(rows, rows.dropFirst()).allSatisfy { rising ? $1 <= $0 + 1 : $1 >= $0 - 1 }
    }
}
