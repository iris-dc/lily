import CoreGraphics
import Testing
import UIKit
@testable import lily

@MainActor
struct TabBarBareCircleTests {
    /// Only a pane no wider than the circle cap qualifies for the glyph swap: the expanded platter, the ~100 pt
    /// tab-switch transient and a pre-layout zero-width pane are never candidates, so the composite on the
    /// expanded bar and the flying selection label are never touched.
    @Test func onlyACircleNarrowPaneQualifies() {
        #expect(TabBarBareCircle.isMinimizedCircle(paneWidth: 48))
        #expect(TabBarBareCircle.isMinimizedCircle(paneWidth: AppConfig.Shell.tabBarCircleMaxWidth))
        #expect(!TabBarBareCircle.isMinimizedCircle(paneWidth: 0))
        #expect(!TabBarBareCircle.isMinimizedCircle(paneWidth: 100))
        #expect(!TabBarBareCircle.isMinimizedCircle(paneWidth: 280))
    }

    /// The condemnation walk condemns a hidden or effectively transparent ancestor below the pane and the
    /// mirror's own flags, but excludes the pane itself — the circle hides at rest by design.
    @Test func theDrawableWalkCondemnsBelowThePaneAndExcludesIt() {
        let pane = UIView()
        let item = UIView()
        let glyph = UIImageView()
        pane.addSubview(item)
        item.addSubview(glyph)
        #expect(TabBarBareCircle.isDrawable(glyph, upTo: pane))
        item.isHidden = true
        #expect(!TabBarBareCircle.isDrawable(glyph, upTo: pane))
        item.isHidden = false
        item.alpha = 0
        #expect(!TabBarBareCircle.isDrawable(glyph, upTo: pane))
        item.alpha = 1
        glyph.isHidden = true
        #expect(!TabBarBareCircle.isDrawable(glyph, upTo: pane))
        glyph.isHidden = false
        pane.isHidden = true
        #expect(TabBarBareCircle.isDrawable(glyph, upTo: pane))
    }
}
