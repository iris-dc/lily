import XCTest

/// The group detail's roster and leave against the mock repositories: the owner's row actions (a promotion at once, a
/// removal after confirming), a plain member's rows without actions, a leave that takes the group off Home and Chats
/// without a refresh, and a guest's Tournaments segment on a public group. The caller is a plain member of Kreuzberg
/// Kickers and the owner of Sunday Padel Crew (Tom admin, Ines and Luca members, Priya banned, 6 members); ids mirror
/// `MockGroupFixtures`, identifiers `AccessibilityIdentifiers(+Groups)`.
final class LilyRosterTests: LilyUITestCase {
    private let kickersRow = "group-row-mock-group-kickers"
    private let padelRow = "group-row-mock-group-padel"
    private let kickersCupRow = "tournament-row-mock-tournament-kickers-cup"

    /// A public group's detail stays after the leave, offering Join; Home and Chats drop the group at once, because
    /// the detail's write to Mine is what both draw.
    @MainActor
    func testLeavingAGroupFromTheDetailRemovesItFromHome() {
        tapSignInWithApple()
        openGroupFromHome(kickersRow)
        let more = app.buttons["group-more"]
        XCTAssertTrue(more.waitForExistence(timeout: 10))
        more.tap()
        let leave = app.buttons["group-leave"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5), "a member may leave")
        leave.tap()
        confirm("Leave group")
        XCTAssertTrue(app.buttons["group-join"].waitForExistence(timeout: 10), "a public group's detail stays, offering Join")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[kickersRow].waitForNonExistence(timeout: 10), "Home drops the group without a refresh")
        openChatsTab()
        XCTAssertTrue(app.buttons[kickersRow].waitForNonExistence(timeout: 10), "its room leaves Chats with it")
    }

    @MainActor
    func testAnOwnerPromotesAMemberFromTheRosterMenu() {
        tapSignInWithApple()
        openGroupFromHome(padelRow)
        openMembers()
        let makeAdmin = app.buttons["Make admin"]
        openMenu(on: app.buttons["member-row-mock-user-ines"], until: makeAdmin)
        makeAdmin.tap()

        let promoted = app.buttons.matching(identifier: "member-row-mock-user-ines")
            .matching(NSPredicate(format: "label CONTAINS %@", "Admin")).firstMatch
        XCTAssertTrue(promoted.waitForExistence(timeout: 10), "the row wears the Admin badge")
    }

    /// The header shows the group the backend answered, so the count follows the removal without a reload.
    @MainActor
    func testAnOwnerRemovesAMemberAfterConfirming() {
        tapSignInWithApple()
        openGroupFromHome(padelRow)
        XCTAssertTrue(labelled("6 members").waitForExistence(timeout: 10), "the header counts the roster before the removal")
        openMembers()
        let luca = app.buttons["member-row-mock-user-luca"]
        let remove = app.buttons["Remove"]
        openMenu(on: luca, until: remove)
        remove.tap()
        confirm("Remove")

        XCTAssertTrue(luca.waitForNonExistence(timeout: 10), "the row is gone")
        XCTAssertTrue(labelled("5 members").waitForExistence(timeout: 10), "the header counts one fewer")
    }

    /// A plain member's long press on a row offers nothing: no menu is attached where the caller has no action, so
    /// the press is a tap and opens the person's profile (seen on the simulator 2026-10-11); pressed again when the
    /// runner turned it into a scroll.
    @MainActor
    func testAPlainMemberGetsNoActionsOnTheRoster() {
        tapSignInWithApple()
        openGroupFromHome(kickersRow)
        openMembers()
        let dev = app.buttons["member-row-mock-user-dev"]
        scrollUntilHittable(dev)
        let profile = app.navigationBars["Dev"]
        var presses = 0
        while !profile.exists && presses < 3 {
            dev.press(forDuration: 1)
            XCTAssertFalse(app.buttons["Remove"].waitForExistence(timeout: 2), "a plain member removes nobody")
            XCTAssertFalse(app.buttons["Make admin"].exists)
            XCTAssertFalse(app.buttons["Ban"].exists)
            _ = profile.waitForExistence(timeout: 5)
            presses += 1
        }
        XCTAssertTrue(profile.exists, "without a menu the press is a tap: the profile opens and nothing lifts")
    }

    /// A public group's tournaments are open to anyone, so a guest gets the Events | Tournaments picker without Members.
    @MainActor
    func testAGuestSeesTheTournamentsSegmentOfAPublicGroup() {
        relaunchAsGuest()
        // Kickers heads the carousel's second column, which peeks in at the right edge far enough to tap.
        let kickers = app.buttons[kickersRow]
        XCTAssertTrue(kickers.waitForExistence(timeout: 10))
        kickers.tap()

        let picker = app.segmentedControls["group-section"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "a public group offers a guest Events | Tournaments")
        XCTAssertFalse(picker.buttons["Members"].exists, "the roster is for signed-in callers")
        picker.buttons["Tournaments"].tap()
        XCTAssertTrue(app.buttons[kickersCupRow].waitForExistence(timeout: 10), "the segment lists the Kickers Cup")
    }

    // MARK: - Helpers

    /// Opens a group's detail from its row on Home.
    @MainActor
    private func openGroupFromHome(_ row: String) {
        openHomeTab()
        let group = app.buttons[row]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        group.tap()
    }

    /// Picks the Members segment of the open detail.
    @MainActor
    private func openMembers() {
        let picker = app.segmentedControls["group-section"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.buttons["Members"].tap()
    }

    /// Long-presses `row` until its menu offers `item`, up to three times: the GitHub runner has turned one press into
    /// a scroll (2026-10-09).
    @MainActor
    private func openMenu(on row: XCUIElement, until item: XCUIElement) {
        scrollUntilHittable(row)
        var presses = 0
        while !item.exists && presses < 3 {
            row.press(forDuration: 1.2)
            _ = item.waitForExistence(timeout: 5)
            presses += 1
        }
        XCTAssertTrue(item.exists, "the row's menu must offer the action")
    }

    /// Taps `title` in the confirmation a destructive action raised; a popover on iPhone, still a sheet to XCUITest.
    @MainActor
    private func confirm(_ title: String) {
        let button = app.sheets.firstMatch.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "the confirmation must offer \(title)")
        button.tap()
    }
}
