import XCTest

/// The states no happy path reaches: a full game's disabled Join, the root-mounted error popup and the failed-load
/// state on Explore, and the landing at an accessibility Dynamic Type size.
final class LilyStateTests: LilyUITestCase {
    /// UIKit honours the content size category named at launch; this is `UIContentSizeCategory
    /// .accessibilityExtraExtraExtraLarge`'s raw value, the largest size (AX5).
    private static let accessibilitySizeArguments = ["-UIPreferredContentSizeCategoryName",
                                                     "UICTContentSizeCategoryAccessibilityXXXL"]
    /// A capsule is 50 pt at the default size; at AX5 its text alone is taller, so a frame under this means the
    /// launch argument was not applied and the walk would prove nothing.
    private static let grownCapsuleHeight: CGFloat = 60

    /// "Pickup at the Cage" is 8 of 8 and unjoined, so its control is the disabled "Event is full" and its bar reads
    /// "Full"; "Bouldering intro" has 6 in for the 4 it needs and allows extras, so it still offers Join and its bar
    /// counts: the two states `PlayerLimit` tells apart.
    @MainActor
    func testAFullGameShowsTheDisabledJoin() {
        tapSignInWithApple()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        openExploreCard("Pickup at the Cage")

        let full = app.buttons["Event is full"]
        XCTAssertTrue(full.waitForExistence(timeout: 5), "a full game's control reads Event is full")
        XCTAssertFalse(full.isEnabled, "and takes no tap")
        XCTAssertTrue(app.staticTexts["Full"].exists, "the bar's label reads Full, not a count")
        XCTAssertFalse(app.buttons["Join"].exists)
        attachScreenshot(named: "event-full")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))
        openExploreCard("Bouldering intro")

        let join = app.buttons["Join"]
        XCTAssertTrue(join.waitForExistence(timeout: 5))
        assertBecomesEnabled(join, "a game past its number that allows extras still offers Join")
        XCTAssertTrue(app.staticTexts["6 joined · 4 needed"].exists)
        attachScreenshot(named: "event-extras-allowed")
    }

    /// The mock's first list load fails: the error reaches the popup mounted on the root, Explore shows its failed
    /// state under the carousels and clear of the floating tab bar, keeps it (a failed load waits before it asks again
    /// on its own), and a pull-to-refresh asks at once. The popup is held open for the run (it fades after four
    /// seconds on its own, which on the runner was before the test had looked) and dismissed with the swipe up.
    @MainActor
    func testAFailedExploreLoadShowsThePopupAndRecoversOnRefresh() {
        relaunch(appendingArguments: ["-mock-events-fail", "-start-as-guest", "-hold-popups"])
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 5))

        // The popup combines its children into one element, so its Dismiss is not tappable apart.
        let popup = labelled("You're offline")
        XCTAssertTrue(popup.waitForExistence(timeout: 10), "a failed load reaches the root-mounted popup")
        waitUntilHittableAndStill(popup)
        XCTAssertTrue(popup.isHittable, "drawn above the shell with no sheet in the way")
        attachScreenshot(named: "explore-load-failed")
        XCTAssertTrue(labelled("Couldn't load events").waitForExistence(timeout: 5), "the list shows its failed state")
        let hint = labelled("Pull down to try again.")
        XCTAssertTrue(hint.exists)
        XCTAssertLessThanOrEqual(hint.frame.maxY,
                                 app.tabBars.firstMatch.frame.minY,
                                 "the failed state is readable above the floating tab bar at rest")
        XCTAssertFalse(app.staticTexts["Sunset 5-a-side"].exists)
        popup.swipeUp()
        XCTAssertTrue(popup.waitForNonExistence(timeout: 5), "a swipe up dismisses the popup")

        pullToRefresh()
        XCTAssertTrue(app.staticTexts["Sunset 5-a-side"].waitForExistence(timeout: 10),
                      "the refresh asks again and the second answer lists the games")
        XCTAssertFalse(labelled("Couldn't load events").exists)
    }

    /// At an accessibility size the pager is a plain scroll and the two ways in stay outside it, and the sign-in sheet
    /// still fits every provider.
    @MainActor
    func testTheLandingAtAccessibilitySizeReachesEveryButton() {
        relaunch(appendingArguments: Self.accessibilitySizeArguments)
        XCTAssertTrue(app.staticTexts["near you."].waitForExistence(timeout: 10))

        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(signIn.frame.height, Self.grownCapsuleHeight, "the launch runs at the accessibility size")
        XCTAssertTrue(signIn.isHittable, "the ways in are reachable without a scroll")
        XCTAssertTrue(app.buttons["Explore events"].isHittable)
        attachScreenshot(named: "landing-ax5")
        scrollUntilHittable(app.staticTexts["or set one up."], maxSwipes: 8)
        XCTAssertTrue(signIn.isHittable, "the buttons sit outside the scroll")

        openSignInSheet()
        let apple = app.buttons["Continue with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue with Email"].isHittable, "every provider fits the sheet at AX5")
        XCTAssertTrue(apple.isHittable)
        apple.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
    }

    /// Opens the Explore card titled `title`; the later cards sit below the fold, so the list scrolls to it first.
    @MainActor
    private func openExploreCard(_ title: String) {
        let target = card(containing: title)
        _ = target.waitForExistence(timeout: 10)
        scrollUntilHittable(target)
        target.tap()
    }
}
