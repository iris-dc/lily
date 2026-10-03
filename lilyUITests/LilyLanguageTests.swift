import XCTest

/// The language setting on Profile: a pick applies at once, across the whole shell, and English comes back the same way.
/// `-reset-session` in the shared launch forgets the choice, so no later test inherits it.
final class LilyLanguageTests: LilyUITestCase {
    @MainActor
    func testPickingALanguageOnProfileRelabelsTheAppAtOnce() {
        relaunchAsGuest()
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))

        let picker = app.buttons["profile-language"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let russian = app.buttons["Русский"]
        XCTAssertTrue(russian.waitForExistence(timeout: 5), "the menu lists every language by its own name")
        russian.tap()

        XCTAssertTrue(app.navigationBars["Профиль"].waitForExistence(timeout: 5), "the screen relabels without a relaunch")
        XCTAssertTrue(app.tabBars.buttons["Обзор"].exists, "the tab bar follows too")
        XCTAssertTrue(app.staticTexts["Вы просматриваете как гость"].exists)

        app.buttons["profile-language"].tap()
        let english = app.buttons["English"]
        XCTAssertTrue(english.waitForExistence(timeout: 5))
        english.tap()

        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
    }
}
