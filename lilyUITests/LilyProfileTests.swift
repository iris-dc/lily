import XCTest

/// The rows behind the profile sheet (opened from the corner button on every tab root). The contact form (on Settings once signed in; a guest's inline row signs them in
/// first): a user picks what the message is about, writes it and is thanked; the mock accepts the send, so no backend
/// is needed. The currency row on Settings: a pick changes the currency the create form's price and the filter's cap
/// are typed in. The display name: a new account starts as the backend's "Player" and chooses a name on the card; the
/// "About you" card writes the bio. And Sign out, at the end of Settings: it returns to the landing and forgets the
/// session.
final class LilyProfileTests: LilyUITestCase {
    /// The symbol the en_US simulator shows for złoty is the code itself; a Polish device shows "zł".
    private static let zlotySymbols: Set<String> = ["PLN", "zł"]

    @MainActor
    func testPickingACurrencyOnProfileChangesThePriceFieldsSymbol() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileSheet()
        openSettings()

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

        closeProfileSheet()
        openExploreTab()
        tapCreateButton()
        walkEventWizardToPlayers(title: "Price check", place: "Canal Path")
        // The price card is the final step's last; a card below the fold may be out of the tree on a 6.1-inch phone.
        let symbol = app.descendants(matching: .any)["create-price-currency"]
        scrollUntilHittable(symbol)
        XCTAssertTrue(Self.zlotySymbols.contains(symbol.label), "the price field is in złoty now: \(symbol.label)")
        discardWizard()

        app.buttons["events-filter"].tap()
        let capSymbol = app.staticTexts["filter-price-currency"]
        XCTAssertTrue(capSymbol.waitForExistence(timeout: 5))
        XCTAssertTrue(Self.zlotySymbols.contains(capSymbol.label), "the price cap too: \(capSymbol.label)")
    }

    @MainActor
    func testSendingFeedbackFromProfileThanksTheUser() {
        relaunchAsGuest()
        openProfileSheet()

        let row = app.buttons["profile-feedback"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5), "a guest is offered to sign in first")
        apple.tap()
        XCTAssertTrue(app.buttons["profile-settings"].waitForExistence(timeout: 10), "the signed-in root offers Settings")

        openSettings()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the contact row lives on Settings now")
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
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    /// A new account's public name is the backend's default until the user picks one: the card says so, the sheet saves
    /// a changed name only, and the header shows the backend's answer.
    @MainActor
    func testChoosingADisplayNameOnProfileShowsIt() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileSheet()
        XCTAssertTrue(app.staticTexts["Player"].waitForExistence(timeout: 5), "a new account starts as the backend's default")
        let nudge = app.staticTexts["Choose a name other players will see"]
        XCTAssertTrue(nudge.waitForExistence(timeout: 5), "the card nudges while the default stands")

        app.buttons["profile-name"].tap()
        XCTAssertTrue(app.navigationBars["Display name"].waitForExistence(timeout: 5))
        let save = app.buttons["profile-name-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "nothing to save until the name changed")
        replaceText(in: app.textFields["profile-name-field"], with: "Alex Kim")
        assertBecomesEnabled(save, "a changed valid name enables Save")
        save.tap()

        XCTAssertTrue(app.navigationBars["Display name"].waitForNonExistence(timeout: 10), "the sheet closes on the answer")
        XCTAssertTrue(app.staticTexts["Alex Kim"].waitForExistence(timeout: 5), "the header shows the backend's answer")
        XCTAssertTrue(app.staticTexts["What other players see"].waitForExistence(timeout: 5), "the nudge is over")
        XCTAssertFalse(app.staticTexts["Player"].exists)
    }

    /// A new account has nothing written about itself: the card nudges, the sheet saves a changed text only, and the
    /// card then shows what was written.
    @MainActor
    func testWritingAboutYouOnProfileShowsIt() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileSheet()
        let card = app.buttons["profile-about"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.contains("Tell other players about yourself"), "the card nudges while nothing is written")

        card.tap()
        XCTAssertTrue(app.navigationBars["About you"].waitForExistence(timeout: 5))
        let save = app.buttons["profile-about-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled, "nothing to save until something was written")
        enter("Padel on Sundays, football when it rains.", into: app.descendants(matching: .any)["profile-about-field"])
        assertBecomesEnabled(save, "a written text enables Save")
        save.tap()

        XCTAssertTrue(app.navigationBars["About you"].waitForNonExistence(timeout: 10), "the sheet closes on the answer")
        XCTAssertTrue(waitUntil(card, holds: "label CONTAINS %@", "Padel on Sundays, football when it rains."),
                      "the card shows what was written: \(card.label)")
    }

    /// Sign out at the end of Settings returns to the landing and forgets the session: the next way in is a guest's.
    @MainActor
    func testSigningOutReturnsToTheLanding() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileSheet()
        XCTAssertTrue(app.staticTexts["apple@example.com"].waitForExistence(timeout: 5))
        openSettings()

        tapAfterScrolling(app.buttons["settings-sign-out"])
        let enter = app.buttons["Explore events"]
        XCTAssertTrue(enter.waitForExistence(timeout: 10), "a sign-out returns to the landing")
        XCTAssertTrue(app.tabBars.firstMatch.waitForNonExistence(timeout: 5), "the shell's bar goes once the landing covers it")

        enter.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        openHomeTab()
        XCTAssertTrue(app.staticTexts["You're browsing as a guest"].waitForExistence(timeout: 5), "the session was forgotten")
        XCTAssertFalse(app.buttons[MockIDs.kickersRow].exists)
    }
}
