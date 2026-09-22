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
}
