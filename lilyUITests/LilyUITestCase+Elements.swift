import XCTest

/// Element-level primitives shared by every test class: a row's text, a scroll-and-tap for a lazy row, a predicate
/// wait and the confirmation taps. In their own file because the base file is at its length limit.
extension LilyUITestCase {
    /// Label and value of a row, since a form row may expose its text as either.
    @MainActor
    func text(of element: XCUIElement) -> String {
        "\(element.label)|\(element.value as? String ?? "")"
    }

    /// Scrolls `element` into a hittable position and taps it. The existence wait's result is discarded on purpose: a
    /// lazy row below the fold is not in the tree until a scroll instantiates it, so the scroll decides, not the wait.
    @MainActor
    func tapAfterScrolling(_ element: XCUIElement,
                           _ message: String = "element never scrolled into a hittable position",
                           direction: ScrollDirection = .up) {
        _ = element.waitForExistence(timeout: 10)
        scrollUntilHittable(element, message, direction: direction)
        element.tap()
    }

    /// Whether `element` satisfies the predicate `format` within `timeout`. An unregistered expectation on its own
    /// `XCTWaiter`, so it never collides with a test's `waitForExpectations`.
    @MainActor
    @discardableResult
    func waitUntil(_ element: XCUIElement, holds format: String, _ args: CVarArg..., timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: format, argumentArray: args)
        let holds = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [holds], timeout: timeout) == .completed
    }

    /// Taps `title` in the confirmation a destructive action raised: a button's bottom sheet or a toolbar Menu's
    /// popover, both `app.sheets` to XCUITest.
    @MainActor
    func confirm(_ title: String) {
        let button = app.sheets.firstMatch.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "the confirmation must offer \(title)")
        button.tap()
    }

    /// Taps `title` in the alert a destructive action raised.
    @MainActor
    func confirmAlert(_ title: String) {
        let confirmation = app.alerts.firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "the confirmation asks first")
        confirmation.buttons[title].tap()
    }
}
