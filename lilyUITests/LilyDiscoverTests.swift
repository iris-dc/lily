import XCTest

/// Relevance on Explore against the mock repositories: the groups carousel and Discover come nearest first around the
/// mock position and show each group's place and distance, and a public group is founded with a place that its detail
/// then shows. Identifiers mirror `AccessibilityIdentifiers+Groups`; the mock ids mirror `MockGroupFixtures`.
final class LilyDiscoverTests: LilyUITestCase {
    private let volleyRow = "group-row-mock-group-volley"
    private let kickersRow = "group-row-mock-group-kickers"

    /// The tiles carry the place and the distance from the mock position; Discover lists the nearest group first and
    /// its cards show the same place line.
    @MainActor
    func testCarouselAndDiscoverShowPlacesAndDistancesNearestFirst() {
        relaunchAsGuest()
        let volley = app.buttons[volleyRow]
        XCTAssertTrue(volley.waitForExistence(timeout: 10), "the carousel shows public groups to a guest")
        XCTAssertTrue(volley.label.contains("Beach Mitte"), "the tile names the place: \(volley.label)")
        XCTAssertTrue(volley.label.contains(" km") || volley.label.contains(" m"), "the tile shows the distance: \(volley.label)")

        app.buttons["groups-see-all"].tap()
        XCTAssertTrue(app.navigationBars["Discover groups"].waitForExistence(timeout: 5))
        let firstCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'group-row-'")).firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertEqual(firstCard.identifier, volleyRow, "the nearest group comes first")
        XCTAssertTrue(firstCard.label.contains("Beach Mitte"), "the card names the place: \(firstCard.label)")
        XCTAssertTrue(app.buttons[kickersRow].exists, "every public group is on Discover")
    }

    /// A public group needs a place: Create stays off until one is named (the spot comes from the mock position), and
    /// the detail and Home then show the new group with its place.
    @MainActor
    func testCreatingAPublicGroupNeedsAPlaceThatTheDetailShows() {
        tapSignInWithApple()
        tapCreateMenuItem("New group")
        XCTAssertTrue(app.navigationBars["New group"].waitForExistence(timeout: 5))

        let name = "Thursday Runners"
        enter(name, into: app.textFields["create-group-name"])
        let submit = app.buttons["create-group-submit"]
        XCTAssertFalse(submit.isEnabled, "a public group without a place cannot be created")
        XCTAssertTrue(app.staticTexts["Name the place where the group plays"].waitForExistence(timeout: 5),
                      "the footer names what is missing once the name is typed (a CI runner needed the wait, 2026-10-09)")

        let place = "Görli Clubhouse"
        enter(place, into: app.textFields["create-group-location-name"])
        XCTAssertTrue(submit.isEnabled, "name, place and the mock position complete the draft")
        submit.tap()

        XCTAssertTrue(app.navigationBars["New group"].waitForNonExistence(timeout: 10), "the sheet must close once created")
        XCTAssertTrue(app.buttons["group-open-chat"].waitForExistence(timeout: 10), "the founder must land in the new group")
        XCTAssertTrue(labelled(name).exists, "the detail must be the new group's")
        XCTAssertTrue(labelled(place).exists, "the detail must show where the group plays")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(labelled(name).waitForExistence(timeout: 10), "the new group must be listed on Home")
    }
}
