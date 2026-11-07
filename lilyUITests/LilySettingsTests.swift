import XCTest

/// The Settings screen pushed from the profile root: a signed-in user finds the language, currency and contact rows,
/// the two legal links and Sign out at the end; a guest keeps the three rows inline on Profile and gets no Settings
/// link; a language picked inside Settings relabels the screen in place without popping it; and Sign out from Settings
/// returns to the landing.
final class LilySettingsTests: LilyUITestCase {
    @MainActor
    func testSettingsFromProfileListsEveryRow() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileTab()
        XCTAssertTrue(app.buttons["profile-settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Sign out"].exists, "Sign out moved off the profile root into Settings")
        XCTAssertFalse(app.buttons["profile-language"].exists, "the preference rows moved into Settings")

        openSettings()
        XCTAssertTrue(app.buttons["profile-language"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile-currency"].exists)
        XCTAssertTrue(app.buttons["profile-feedback"].exists)
        XCTAssertTrue(app.buttons["settings-privacy"].exists)
        XCTAssertTrue(app.buttons["settings-terms"].exists)
        XCTAssertTrue(app.buttons["settings-sign-out"].exists, "Sign out ends the list")
    }

    @MainActor
    func testGuestProfileKeepsItsRowsInlineAndGetsNoSettings() {
        relaunchAsGuest()
        openProfileTab()

        XCTAssertTrue(app.buttons["profile-language"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile-currency"].exists)
        XCTAssertTrue(app.buttons["profile-feedback"].exists)
        XCTAssertFalse(app.buttons["profile-settings"].exists, "a guest gets no Settings screen")
        XCTAssertFalse(app.buttons["settings-sign-out"].exists)
    }

    /// The pick applies to the pushed screen in place: the push survives and relabels, and English comes back the same
    /// way. `-reset-session` in the shared launch forgets the choice, so no later test inherits it.
    @MainActor
    func testPickingALanguageInSettingsRelabelsItInPlace() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileTab()
        openSettings()

        app.buttons["profile-language"].tap()
        let russian = app.buttons["Русский"]
        XCTAssertTrue(russian.waitForExistence(timeout: 5), "the menu lists every language by its own name")
        russian.tap()

        XCTAssertTrue(app.navigationBars["Настройки"].waitForExistence(timeout: 5),
                      "the pushed screen relabels without popping")
        let currency = app.buttons["profile-currency"]
        XCTAssertTrue(waitUntil(currency, holds: "label CONTAINS %@", "Валюта"),
                      "every row relabels in place: \(currency.label)")

        app.buttons["profile-language"].tap()
        let english = app.buttons["English"]
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSigningOutFromSettingsReturnsToTheLanding() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileTab()
        openSettings()

        tapAfterScrolling(app.buttons["settings-sign-out"])
        XCTAssertTrue(app.buttons["Explore events"].waitForExistence(timeout: 10), "a sign-out returns to the landing")
        XCTAssertTrue(app.tabBars.firstMatch.waitForNonExistence(timeout: 5), "the shell's bar goes once the landing covers it")
    }
}
