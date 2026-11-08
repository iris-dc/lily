import XCTest

/// The language setting on the profile sheet: a pick applies at once, the sheet re-renders in place while the tabs
/// rebuild underneath (it mounts above the language-identity boundary), and English comes back the same way.
/// `-reset-session` in the shared launch forgets the choice, so no later test inherits it.
final class LilyLanguageTests: LilyUITestCase {
    @MainActor
    func testPickingALanguageOnProfileRelabelsTheAppAtOnce() {
        relaunchAsGuest()
        openProfileSheet()

        let picker = app.buttons["profile-language"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let russian = app.buttons["Русский"]
        XCTAssertTrue(russian.waitForExistence(timeout: 5), "the menu lists every language by its own name")
        russian.tap()

        XCTAssertTrue(app.navigationBars["Профиль"].waitForExistence(timeout: 5), "the sheet relabels in place, without closing")
        XCTAssertTrue(app.staticTexts["Вы авторизованы как гость"].exists)
        let currency = app.buttons["profile-currency"]
        XCTAssertTrue(currency.label.contains("Валюта"), "every profile card relabels in place: \(currency.label)")
        let contact = app.buttons["profile-feedback"]
        XCTAssertTrue(contact.label.contains("Обратная связь"), "the contact card too: \(contact.label)")

        closeProfileSheet()
        XCTAssertTrue(app.tabBars.buttons["Обзор"].waitForExistence(timeout: 5), "the tabs rebuilt under the sheet")

        app.buttons["profile-corner"].tap()
        XCTAssertTrue(app.navigationBars["Профиль"].waitForExistence(timeout: 5))
        app.buttons["profile-language"].tap()
        let english = app.buttons["English"]
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.tap()

        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
    }
}
