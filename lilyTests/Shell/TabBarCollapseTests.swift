import CoreGraphics
import Testing
@testable import lily

@MainActor
struct TabBarCollapseTests {
    /// The SE's measured panes: the expanded platter 274 pt, the minimized circle 48 pt, the bar 375 pt.
    @Test func theWideExpandedPlatterReadsAsExpanded() {
        #expect(!TabBarCollapse.isMinimized(visiblePaneWidths: [274], barWidth: 375))
    }

    @Test func theSmallCircleAloneReadsAsMinimized() {
        #expect(TabBarCollapse.isMinimized(visiblePaneWidths: [48], barWidth: 375))
    }

    /// Mid-swap both panes show; the bar reads as expanded, so the badge errs on showing.
    @Test func bothPanesVisibleReadAsExpanded() {
        #expect(!TabBarCollapse.isMinimized(visiblePaneWidths: [274, 48], barWidth: 375))
    }

    @Test func noVisiblePaneOrNoBarReadsAsExpanded() {
        #expect(!TabBarCollapse.isMinimized(visiblePaneWidths: [], barWidth: 375))
        #expect(!TabBarCollapse.isMinimized(visiblePaneWidths: [48], barWidth: 0))
    }

    /// Pre-layout panes report zero width: no laid-out pane is no signal, and the fail-safe answer is expanded —
    /// a wrong "minimized" would hide the badge with no later KVO event to correct it.
    @Test func zeroWidthPanesReadAsExpanded() {
        #expect(!TabBarCollapse.isMinimized(visiblePaneWidths: [0], barWidth: 375))
        #expect(!TabBarCollapse.isMinimized(visiblePaneWidths: [0, 0], barWidth: 375))
    }

    /// Exactly half the bar is no circle: the rule is strict, so only a clearly small pane hides the badge.
    @Test func theMidpointItselfReadsAsExpanded() {
        #expect(!TabBarCollapse.isMinimized(visiblePaneWidths: [187.5], barWidth: 375))
    }
}
