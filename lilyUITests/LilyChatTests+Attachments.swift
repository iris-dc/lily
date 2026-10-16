import XCTest

/// Attachment helpers of `LilyChatTests`, split out to keep the class under SwiftLint's type-body limit. Helpers only:
/// XCTest does not discover a test declared in an extension unless it is `@objc`.
extension LilyChatTests {
    enum Swipe {
        case left
        case right
    }

    /// Signs in and opens the Kreuzberg Kickers room with the mock picker, whose "Photo library" hands over the bundled
    /// photo, whose "Camera" the bundled clip and whose "File" the bundled document.
    @MainActor
    func openKickersRoomWithMockPicker() {
        relaunch(appending: "-mock-attachment-picker")
        tapSignInWithApple()
        openRoom("group-row-mock-group-kickers", titled: "Kreuzberg Kickers")
    }

    /// Opens the composer's attach menu and picks `item` ("Photo library", "Camera" or "File").
    @MainActor
    func pickFromAttachMenu(_ item: String) {
        let attach = app.buttons["chat-attach"]
        XCTAssertTrue(attach.waitForExistence(timeout: 5), "the composer offers the attach menu")
        attach.tap()
        let choice = app.buttons[item]
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "the menu offers \(item)")
        choice.tap()
    }

    /// Opens the Kickers room with the mock picker, picks `item` from the attach menu and answers the strip once the
    /// pick shows in it.
    @MainActor
    @discardableResult
    func attachFromKickersRoom(_ item: String) -> XCUIElement {
        openKickersRoomWithMockPicker()
        pickFromAttachMenu(item)
        let strip = app.descendants(matching: .any)["chat-attachment-strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 10), "the pick shows above the field")
        return strip
    }

    /// Picks `count` photos one by one through the attach menu and waits until the strip shows a tile for each.
    @MainActor
    func attachPhotosFromTheMockLibrary(_ count: Int) {
        for _ in 0..<count {
            pickFromAttachMenu("Photo library")
        }
        let removes = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chat-attachment-remove-'"))
        XCTAssertTrue(removes.element(boundBy: count - 1).waitForExistence(timeout: 10), "the strip shows every pick")
    }

    /// Sends once the uploads are done and waits until the bubble draws exactly `count` picture tiles, which it answers.
    @MainActor
    func sendAndWaitForTiles(_ count: Int) -> XCUIElementQuery {
        let send = app.buttons["chat-send"]
        assertBecomesEnabled(send, "Send opens once the uploads are done", timeout: 30)
        send.tap()
        let tiles = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'message-attachment-image-'"))
        XCTAssertTrue(tiles.element(boundBy: count - 1).waitForExistence(timeout: 10), "the sent message shows its tiles")
        XCTAssertEqual(tiles.count, count, "the gallery draws no more than \(count) tiles")
        return tiles
    }

    /// Taps a gallery tile at its lower edge, clear of the "+N" caption a last tile carries at its centre.
    @MainActor
    func openTile(_ tile: XCUIElement) {
        tile.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
    }

    /// Whether the viewer's caption reads `position` ("5 / 5") within a few seconds.
    @MainActor
    func viewerShows(_ position: String) -> Bool {
        app.staticTexts["attachment-viewer-position"].wait(for: \.label, toEqual: position, timeout: 5)
    }

    /// Swipes the viewer `direction` once per caption and answers whether each shows in turn; a caption repeated means
    /// the swipe must have changed nothing (the first or the last page). A swipe the page controller lost (on the runner
    /// the last page was still settling when it landed) is repeated once; when a caption never comes, the one the viewer
    /// stopped on is recorded with a screenshot, so a failure names the page.
    @MainActor
    func viewerShows(_ positions: [String], swiping direction: Swipe) -> Bool {
        let viewer = app.descendants(matching: .any)["attachment-viewer"]
        let caption = app.staticTexts["attachment-viewer-position"]
        for position in positions {
            letTheViewerSettle()
            swipe(viewer, direction)
            if caption.wait(for: \.label, toEqual: position, timeout: 5) { continue }
            letTheViewerSettle()
            swipe(viewer, direction)
            if caption.wait(for: \.label, toEqual: position, timeout: 5) { continue }
            XCTContext.runActivity(named: "the viewer stopped at \(caption.label), not \(position)") { _ in
                attachScreenshot(named: "attachment-viewer-page")
            }
            return false
        }
        return true
    }

    /// A slow swipe: a flick on a slow simulator is read late and lands in the middle of the page scroll it started.
    @MainActor
    private func swipe(_ viewer: XCUIElement, _ direction: Swipe) {
        switch direction {
        case .left: viewer.swipeLeft(velocity: .slow)
        case .right: viewer.swipeRight(velocity: .slow)
        }
    }

    /// Waits out the cover's presentation or the page scroll the last swipe started: XCUITest's idle wait covers
    /// neither, and a swipe during either is lost; the runner needs twice a Mac's moment.
    @MainActor
    private func letTheViewerSettle() {
        _ = app.staticTexts["never-there"].waitForExistence(timeout: 2)
    }
}
