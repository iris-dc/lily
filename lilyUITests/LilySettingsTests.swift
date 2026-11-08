import XCTest

/// The Settings screen pushed from the profile root: a signed-in user finds the language, currency and contact rows,
/// the two legal rows and Sign out at the end; the privacy row pushes the policy in place; a guest keeps the three
/// rows inline on Profile and gets no Settings link; a language picked inside Settings relabels the screen in place
/// without popping it; and Sign out from Settings returns to the landing.
final class LilySettingsTests: LilyUITestCase {
    @MainActor
    func testSettingsFromProfileListsEveryRow() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileSheet()
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
        openProfileSheet()

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
        openProfileSheet()
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

    /// The delete flow end to end on the mock backend: the Settings row opens the sheet, the summary shows the mock
    /// counts with the zero-count line dropped and the unconditional messages sentence, the destructive dialog's
    /// confirm runs the locked wait, the one-time acknowledgment shows, and acknowledging lands signed out on the
    /// landing (the pinned teardown order: nothing ends before that tap).
    @MainActor
    func testDeletingTheAccountWalksToTheSignedOutLanding() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileSheet()
        openSettings()
        tapAfterScrolling(app.buttons["settings-delete-account"])

        XCTAssertTrue(labelled("2 groups will pass to another member").waitForExistence(timeout: 5),
                      "the mock plan's counts compose the plural lines")
        XCTAssertTrue(labelled("1 group will be deleted").exists, "one is singular")
        XCTAssertTrue(labelled("Your messages will show as Deleted user.").exists, "the always-true sentence renders")
        XCTAssertFalse(labelled("organize will be cancelled").exists, "a zero count's line is dropped")

        app.buttons["delete-account-confirm"].tap()
        let dialogConfirm = app.buttons["Delete my account"]
        XCTAssertTrue(dialogConfirm.waitForExistence(timeout: 5), "the destructive dialog asks once more")
        dialogConfirm.tap()

        let acknowledge = app.buttons["delete-account-acknowledge"]
        XCTAssertTrue(acknowledge.waitForExistence(timeout: 15), "the poll settles on the mock's tombstone 401")
        XCTAssertTrue(labelled("Your account was deleted").exists)
        acknowledge.tap()
        XCTAssertTrue(app.buttons["Explore events"].waitForExistence(timeout: 10),
                      "only the acknowledge tap ends the session, over the landing")
        XCTAssertTrue(app.tabBars.firstMatch.waitForNonExistence(timeout: 5))
        XCTAssertFalse(labelled("Session expired").waitForExistence(timeout: 2),
                       "the account-deleted end suppresses the expired-session popup over the landing")
    }

    /// `-mock-deleted-user`: the Kickers room carries a line whose sender deleted their account, rendered under the
    /// localized tombstone name instead of the stored placeholder.
    @MainActor
    func testADeletedSendersMessageShowsTheTombstone() {
        relaunch(appending: "-mock-deleted-user")
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openRoom(MockIDs.kickersRow, titled: "Kreuzberg Kickers")

        XCTAssertTrue(app.staticTexts["Deleted user"].waitForExistence(timeout: 10),
                      "the deleted sender's bubble carries the localized name, not the stored placeholder")
        XCTAssertFalse(app.staticTexts["Player"].exists, "the stored placeholder never shows on a flagged row")
    }

    /// The privacy row pushes the policy in place (owner correction 2026-11-08); the date line and the first
    /// section render without a backend, and the terms row stays beside it as the browser link.
    @MainActor
    func testThePrivacyRowPushesThePolicyInApp() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileSheet()
        openSettings()

        tapAfterScrolling(app.buttons["settings-privacy"])
        XCTAssertTrue(app.navigationBars["Privacy policy"].waitForExistence(timeout: 5), "the policy opens in the app")
        XCTAssertTrue(app.otherElements["settings-privacy-policy"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Who we are"].exists, "the first section's heading renders")
        XCTAssertTrue(app.staticTexts["Last updated 8 November 2026."].exists, "the date line opens the screen")
    }

    @MainActor
    func testSigningOutFromSettingsReturnsToTheLanding() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openProfileSheet()
        openSettings()

        tapAfterScrolling(app.buttons["settings-sign-out"])
        XCTAssertTrue(app.buttons["Explore events"].waitForExistence(timeout: 10), "a sign-out returns to the landing")
        XCTAssertTrue(app.tabBars.firstMatch.waitForNonExistence(timeout: 5), "the shell's bar goes once the landing covers it")
    }
}
