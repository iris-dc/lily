import XCTest

/// The creation wizard's walk, shared by every class that creates from the "+": the plain button opens the wizard
/// on its kind page (one auto-advancing card per offered kind), each following step is one idea on the wizard's
/// `NavigationStack`, titled with its name, and `create-next` pushes the following step. The event walk is Name,
/// Type (whose cards auto-advance), When, Hosting group (only where nothing locked a group and the caller has
/// groups to host in), Place, Players, then Details with the submit button. The identifiers mirror
/// `AccessibilityIdentifiers`. In its own file because the base file is at its length limit.
extension LilyUITestCase {
    /// The event flow's final step title, what a submit or discard waits on to see the wizard gone.
    static let wizardFinalEventStep = "Details"

    /// The kind page's navigation title, what tells it from a kind's first step.
    static let wizardKindTitle = "What are you creating?"

    /// Waits for the wizard step titled `title`: each step's navigation title is its name.
    @MainActor
    func waitForWizardStep(_ title: String) {
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 10), "the wizard shows its \(title) step")
    }

    /// Taps the bottom bar's Next once it enables; the step's own fields decide when it does.
    @MainActor
    func tapNext() {
        let next = app.buttons["create-next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        assertBecomesEnabled(next, "the step's fields must allow Next")
        next.tap()
    }

    /// Picks a choice card on the step titled `title`; the pick fixes the choice and pushes the next step itself.
    @MainActor
    func pickWizardCard(_ cardID: String, on title: String) {
        waitForWizardStep(title)
        let card = app.buttons[cardID]
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the \(title) step offers \(cardID)")
        card.tap()
    }

    /// Picks a kind card on the wizard's kind page ("create-kind-event"); the pick fixes the kind one-way and
    /// pushes the kind's first step itself.
    @MainActor
    func pickCreationKind(_ cardID: String) {
        pickWizardCard(cardID, on: Self.wizardKindTitle)
    }

    /// Picks a type by its card on the Type step; the pick fixes the type and pushes the next step itself.
    @MainActor
    func pickWizardEventType(_ wireName: String = "football") {
        pickWizardCard("create-type-\(wireName)", on: "Type")
    }

    /// Walks from the Name step, its title already entered, to Place: a type card (whose tap advances), then Next
    /// past When and the Hosting group step (present from Explore, where nothing locks a group and the mock user
    /// has groups to host in).
    @MainActor
    func walkWizardNameToPlace() {
        tapNext()
        pickWizardEventType()
        waitForWizardStep("When")
        tapNext()
        waitForWizardStep("Hosting group")
        tapNext()
        waitForWizardStep("Place")
    }

    /// Walks the event wizard to its Players step, where the player fields live: the title on Name, the middle
    /// steps, the place name on Place. The spot comes from the mock location, so these two texts complete the draft.
    @MainActor
    func walkEventWizardToPlayers(title: String, place: String) {
        waitForWizardStep("Name")
        enter(title, into: app.textFields["create-title"])
        walkWizardNameToPlace()
        enter(place, into: app.textFields["create-location-name"])
        tapNext()
        waitForWizardStep("Players")
    }

    /// Pushes from the Players step to Details, the final step carrying the price fields and the submit button.
    @MainActor
    func continueToDetails() {
        tapNext()
        waitForWizardStep(Self.wizardFinalEventStep)
    }

    /// Pops one wizard step through the navigation back button, which carries the previous step's title (or plain
    /// "Back" when the bar has no room for the name).
    @MainActor
    func tapWizardBack(from current: String, to previous: String) {
        let bar = app.navigationBars[current]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        let named = bar.buttons[previous]
        (named.exists ? named : bar.buttons["Back"]).tap()
        waitForWizardStep(previous)
    }

    /// Taps the final step's submit once the draft completes and waits for the wizard to close on the answer.
    @MainActor
    func submitWizard() {
        let submit = app.buttons["create-submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        assertBecomesEnabled(submit, "the walked draft must be complete")
        submit.tap()
        XCTAssertTrue(app.navigationBars[Self.wizardFinalEventStep].waitForNonExistence(timeout: 10),
                      "the wizard must close once created")
    }

    /// Cancels a walked wizard from its final step and confirms the discard question a dirty draft raises; a clean
    /// wizard would close silently instead.
    @MainActor
    func discardWizard() {
        app.buttons["create-cancel"].tap()
        confirm("Discard")
        XCTAssertTrue(app.navigationBars[Self.wizardFinalEventStep].waitForNonExistence(timeout: 5),
                      "the wizard must close on discard")
    }
}
