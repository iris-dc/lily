import XCTest

/// The attachment viewer's own gestures; a test in an extension is discovered only when `@objc`.
extension LilyChatTests {
    /// A single picture opened from its tile is dragged away, down, up or sideways, as in Photos: no button needed.
    @objc @MainActor
    func testDraggingThePictureAwayClosesTheViewer() {
        attachFromKickersRoom("Photo library")
        let tiles = sendAndWaitForTiles(1)
        let viewer = app.descendants(matching: .any)["attachment-viewer"]
        let close = app.buttons["attachment-viewer-close"]
        let ends = [CGVector(dx: 0.55, dy: 0.95), CGVector(dx: 0.45, dy: 0.05), CGVector(dx: 0.02, dy: 0.52)]
        for (name, end) in zip(["down", "up", "sideways"], ends) {
            openTile(tiles.firstMatch)
            XCTAssertTrue(viewer.waitForExistence(timeout: 5), "a tap opens the viewer")
            XCTAssertTrue(close.waitForExistence(timeout: 5))
            let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: close)
            XCTAssertEqual(XCTWaiter().wait(for: [hittable], timeout: 5), .completed, "the zoom in has settled")
            let middle = viewer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            middle.press(forDuration: 0.05,
                         thenDragTo: viewer.coordinate(withNormalizedOffset: end),
                         withVelocity: .fast,
                         thenHoldForDuration: 0)
            XCTAssertTrue(viewer.waitForNonExistence(timeout: 5), "a drag \(name) closes the viewer")
        }
    }
}
