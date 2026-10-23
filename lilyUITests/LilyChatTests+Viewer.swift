import XCTest

/// The attachment viewer's own gestures; a test in an extension is discovered only when `@objc`.
extension LilyChatTests {
    /// A picture opened from its tile is dragged away, down or up, as in Photos; a drag sideways does not close it.
    @objc @MainActor
    func testDraggingThePictureUpOrDownClosesTheViewer() {
        attachFromKickersRoom("Photo library")
        let tiles = sendAndWaitForTiles(1)
        let viewer = app.descendants(matching: .any)["attachment-viewer"]
        let close = app.buttons["attachment-viewer-close"]
        let drags = [("down", CGVector(dx: 0.55, dy: 0.95), true),
                     ("up", CGVector(dx: 0.45, dy: 0.05), true),
                     ("sideways", CGVector(dx: 0.02, dy: 0.52), false)]
        for (name, end, closes) in drags {
            openTile(tiles.firstMatch)
            XCTAssertTrue(viewer.waitForExistence(timeout: 5), "a tap opens the viewer")
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: close)
            XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 5), .completed, "the viewer has faded in")
            viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.05,
                       thenDragTo: viewer.coordinate(withNormalizedOffset: end),
                       withVelocity: .fast,
                       thenHoldForDuration: 0)
            if closes {
                XCTAssertTrue(viewer.waitForNonExistence(timeout: 5), "a drag \(name) closes the viewer")
            } else {
                XCTAssertFalse(viewer.waitForNonExistence(timeout: 2), "a drag \(name) leaves the viewer open")
                close.tap()
                XCTAssertTrue(viewer.waitForNonExistence(timeout: 5))
            }
        }
    }
}
