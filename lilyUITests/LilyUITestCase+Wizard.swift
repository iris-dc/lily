import XCTest

/// The creation wizard's walk, shared by every class that creates from the "+": the "+" is a menu naming each offered
/// kind ("New event", "New group", "New tournament"), and picking an item opens the wizard seeded with that kind, so
/// the flow starts on the kind's first step — there is no kind page. Each following step is one idea on the wizard's
/// `NavigationStack`, titled with its name, and `create-next` pushes the following step. The event walk is Name,
/// Type (whose grid cards auto-advance), When, Hosting group (only where nothing locked a group and the caller has
/// groups to host in), Place, Players, then Details with the submit button. The identifiers mirror
/// `AccessibilityIdentifiers`. In its own file because the base file is at its length limit.
extension LilyUITestCase {
    /// The event flow's final step title, what a submit or discard waits on to see the wizard gone.
    static let wizardFinalEventStep = "Details"

    /// Opens the "+" menu and picks the item `title` ("New event"): a signed-in user gets the wizard on the kind's
    /// Name step, a guest the sign-in sheet.
    @MainActor
    func tapCreateMenuItem(_ title: String) {
        tapCreateButton()
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "the + menu offers \(title)")
        item.tap()
    }

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

    /// Picks a type by its card on the Type step's grid; the pick fixes the type and pushes the next step itself.
    @MainActor
    func pickWizardEventType(_ wireName: String = "football") {
        pickWizardCard("create-type-\(wireName)", on: "Type")
    }

    /// Walks from the Name step, its title already entered, to Place: a type card (whose tap advances), then Next
    /// past When (where `onWhen` runs first, for a check on that step) and the Hosting group step (present from
    /// Explore, where nothing locks a group and the mock user has groups to host in).
    @MainActor
    func walkWizardNameToPlace(onWhen: (@MainActor () -> Void)? = nil) {
        tapNext()
        pickWizardEventType()
        waitForWizardStep("When")
        onWhen?()
        tapNext()
        waitForWizardStep("Hosting group")
        tapNext()
        waitForWizardStep("Place")
    }

    /// On the When step: the optional finish time is addable (the picker comes up, proposed after the start) and
    /// removable (the clear button returns the add affordance and the picker goes).
    @MainActor
    func assertFinishTimeAddsAndRemoves() {
        let add = app.buttons["create-ends-at-add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the When step offers adding a finish time")
        add.tap()
        let picker = app.descendants(matching: .any)["create-ends-at"].firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "the add shows the finish-time picker")
        let remove = app.buttons["create-ends-at-remove"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "the set finish time offers its clear button")
        remove.tap()
        XCTAssertTrue(add.waitForExistence(timeout: 5), "the remove returns the add affordance")
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "the picker goes with the finish time")
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
