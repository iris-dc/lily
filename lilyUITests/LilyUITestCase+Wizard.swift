import XCTest

/// The creation wizard's walk, shared by every class that creates an event from the "+" menu: each step is a page on
/// the wizard's `NavigationStack` titled with its name, `create-next` pushes the following step and the final step
/// carries the submit button. The menu entry stays `tapCreateButton()`; the identifiers mirror
/// `AccessibilityIdentifiers`. In its own file because the base file is at its length limit.
extension LilyUITestCase {
    /// The event flow's final step title, what a submit or discard waits on to see the wizard gone.
    static let wizardFinalEventStep = "Players and details"

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

    /// Walks the event wizard from Basics to its final step: the title, Next, the place name, Next. The spot comes
    /// from the mock location, so these two texts complete the draft.
    @MainActor
    func walkEventWizardToPlayers(title: String, place: String) {
        waitForWizardStep("Basics")
        enter(title, into: app.textFields["create-title"])
        tapNext()
        waitForWizardStep("Place")
        enter(place, into: app.textFields["create-location-name"])
        tapNext()
        waitForWizardStep(Self.wizardFinalEventStep)
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
