import XCTest

/// The contact form on Profile: a guest is sent to sign in first, a user picks what the message is about, writes it
/// and is thanked; the mock accepts the send, so no backend is needed. The currency row: a pick changes the
/// currency the create form's price and the filter's cap are typed in. And Sign out: it returns to the landing and
/// forgets the session.
final class LilyProfileTests: LilyUITestCase {
    /// The symbol the en_US simulator shows for złoty is the code itself; a Polish device shows "zł".
    private static let zlotySymbols: Set<String> = ["PLN", "zł"]

    @MainActor
    func testPickingACurrencyOnProfileChangesThePriceFieldsSymbol() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileTab()

        let picker = app.buttons["profile-currency"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(picker.label.contains("System"), "the row starts by following the region: \(picker.label)")
        picker.tap()
        let zloty = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'PLN'")).firstMatch
        XCTAssertTrue(zloty.waitForExistence(timeout: 5), "the menu names each currency by code and name")
        zloty.tap()
        let picked = app.buttons
            .matching(NSPredicate(format: "identifier == 'profile-currency' AND label CONTAINS 'PLN'")).firstMatch
        XCTAssertTrue(picked.waitForExistence(timeout: 5), "the row reads its title and the choice")

        openExploreTab()
        tapCreateButton()
        // The price row is the form's last; a Form row off screen is not in the accessibility tree yet.
        let symbol = app.descendants(matching: .any)["create-price-currency"]
        scrollUntilHittable(symbol)
        XCTAssertTrue(Self.zlotySymbols.contains(symbol.label), "the price field is in złoty now: \(symbol.label)")
        app.buttons["create-cancel"].tap()

        app.buttons["events-filter"].tap()
        let capSymbol = app.staticTexts["filter-price-currency"]
        XCTAssertTrue(capSymbol.waitForExistence(timeout: 5))
        XCTAssertTrue(Self.zlotySymbols.contains(capSymbol.label), "the price cap too: \(capSymbol.label)")
    }

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
        assertBecomesEnabled(send, "a message enables Send")
        send.tap()

        XCTAssertTrue(app.staticTexts["Thanks for writing"].waitForExistence(timeout: 5))
        app.buttons["feedback-done"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
    }

    /// Sign out on Profile returns to the landing and forgets the session: the next way in is a guest's.
    @MainActor
    func testSigningOutReturnsToTheLanding() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileTab()
        XCTAssertTrue(app.staticTexts["Apple Tester"].waitForExistence(timeout: 5))

        let signOut = app.buttons["Sign out"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 5))
        scrollUntilHittable(signOut)
        signOut.tap()
        let enter = app.buttons["Explore events"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "a sign-out returns to the landing")
        XCTAssertTrue(app.tabBars.firstMatch.waitForNonExistence(timeout: 5), "the shell's bar goes once the landing covers it")

        enter.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        openHomeTab()
        XCTAssertTrue(app.staticTexts["You're browsing as a guest"].waitForExistence(timeout: 5), "the session was forgotten")
        XCTAssertFalse(app.buttons["group-row-mock-group-kickers"].exists)
    }
}
