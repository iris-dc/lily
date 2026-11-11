import XCTest

/// Relevance on Explore against the mock repositories: the groups carousel and Discover come nearest first around the
/// mock position and show each group's place and distance, and a public group is founded with a place that its detail
/// then shows. Identifiers mirror `AccessibilityIdentifiers+Groups`; the mock ids mirror `MockGroupFixtures`.
final class LilyDiscoverTests: LilyUITestCase {
    /// The tiles carry the place and the distance from the mock position; Discover lists the nearest group first and
    /// its cards show the same place line.
    @MainActor
    func testCarouselAndDiscoverShowPlacesAndDistancesNearestFirst() {
        relaunchAsGuest()
        let volley = app.buttons[MockIDs.volleyRow]
        XCTAssertTrue(volley.waitForExistence(timeout: 10), "the carousel shows public groups to a guest")
        XCTAssertTrue(volley.label.contains("Beach Mitte"), "the tile names the place: \(volley.label)")
        XCTAssertTrue(volley.label.contains(" km") || volley.label.contains(" m"), "the tile shows the distance: \(volley.label)")

        showDiscover()
        let firstCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'group-row-'")).firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 10))
        XCTAssertEqual(firstCard.identifier, MockIDs.volleyRow, "the nearest group comes first")
        XCTAssertTrue(firstCard.label.contains("Beach Mitte"), "the card names the place: \(firstCard.label)")
        XCTAssertTrue(app.buttons[MockIDs.kickersRow].exists, "every public group is on Discover")
    }

    /// A public group walks the wizard's six steps — Name, the optional Description, Type and Who can join as
    /// auto-advancing cards, Place, then Permissions with the create button. A public group needs a place: Next on
    /// Place stays off until one is named (the spot comes from the mock position), and the detail and Home then show
    /// the new group with its place.
    @MainActor
    func testCreatingAPublicGroupNeedsAPlaceThatTheDetailShows() {
        tapSignInWithApple()
        tapCreateButton()
        pickCreationKind("create-kind-group")

        let name = "Thursday Runners"
        waitForWizardStep("Name")
        enter(name, into: app.textFields["create-group-name"])
        tapNext()
        waitForWizardStep("Description")
        tapNext()
        pickWizardCard("create-type-any", on: "Type")
        pickWizardCard("create-visibility-public", on: "Who can join")
        waitForWizardStep("Place")
        let next = app.buttons["create-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled, "a public group without a place cannot advance")

        let place = "Görli Clubhouse"
        enter(place, into: app.textFields["create-group-location-name"])
        assertBecomesEnabled(next, "name, place and the mock position complete the page")
        next.tap()
        waitForWizardStep("Permissions")
        let submit = app.buttons["create-group-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        assertBecomesEnabled(submit, "the walked draft must be complete")
        submit.tap()

        XCTAssertTrue(app.navigationBars["Permissions"].waitForNonExistence(timeout: 10), "the wizard must close once created")
        XCTAssertTrue(app.buttons["group-open-chat"].waitForExistence(timeout: 10), "the founder must land in the new group")
        XCTAssertTrue(labelled(name).waitForExistence(timeout: 5), "the detail must be the new group's")
        XCTAssertTrue(labelled(place).waitForExistence(timeout: 5), "the detail must show where the group plays")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(labelled(name).waitForExistence(timeout: 10), "the new group must be listed on Home")
    }
}
