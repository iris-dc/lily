import CoreGraphics
import Testing
@testable import lily

@MainActor
struct TabBarCollapseTests {
    /// Measured panes: the minimized circle is 48 pt and the tab-switch transient ~100 pt on every device, while
    /// the platter scales with the bar (274 pt on the SE's 375 pt bar); the 402 pt (17 Pro) and 440 pt (Pro Max)
    /// bars are pinned because a width-relative circle bound misread the transient as the circle there.
    private let bars: [(platter: CGFloat, bar: CGFloat)] = [(274, 375), (294, 402), (322, 440)]

    @Test func thePlatterAloneReadsAsExpandedOnEveryBarWidth() {
        for (platter, bar) in bars {
            #expect(TabBarCollapse.phase(visiblePaneWidths: [platter], barWidth: bar) == .expanded)
        }
    }

    @Test func theCircleReadsAsMinimizedOnEveryBarWidth() {
        for (_, bar) in bars {
            #expect(TabBarCollapse.phase(visiblePaneWidths: [48], barWidth: bar) == .minimized)
            #expect(TabBarCollapse.phase(visiblePaneWidths: [48, 100], barWidth: bar) == .minimized)
        }
    }

    /// The measured morph: the circle pane joins the platter (often with the ~100 pt transient) the moment a
    /// collapse or an expand starts, so both endpoints visible at once is the morphing phase.
    @Test func bothEndpointsVisibleReadAsMorphingOnEveryBarWidth() {
        for (platter, bar) in bars {
            #expect(TabBarCollapse.phase(visiblePaneWidths: [platter, 48, 100], barWidth: bar) == .morphing)
            #expect(TabBarCollapse.phase(visiblePaneWidths: [platter, 48], barWidth: bar) == .morphing)
        }
    }

    /// A churned transient pane beside the platter (a tab switch) is no circle on any width: a quarter-bar bound
    /// read the ~100 pt transient as the circle on bars of 400 pt and up, and the capsule flickered on every tab
    /// change there.
    @Test func aTransientPaneAloneBesideThePlatterStaysExpandedOnEveryBarWidth() {
        for (platter, bar) in bars {
            #expect(TabBarCollapse.phase(visiblePaneWidths: [platter, 100], barWidth: bar) == .expanded)
        }
    }

    /// A mid-size pane alone is neither endpoint: no recognized shape, and the fail-safe errs on showing.
    @Test func anUnrecognizedPaneAloneReadsAsExpanded() {
        #expect(TabBarCollapse.phase(visiblePaneWidths: [100], barWidth: 375) == .expanded)
    }

    @Test func noVisiblePaneOrNoBarReadsAsExpanded() {
        #expect(TabBarCollapse.phase(visiblePaneWidths: [], barWidth: 375) == .expanded)
        #expect(TabBarCollapse.phase(visiblePaneWidths: [48], barWidth: 0) == .expanded)
    }

    /// Pre-layout panes report zero width: no laid-out pane is no signal, and the fail-safe answer is expanded —
    /// a wrong "minimized" would hide the badge with no later KVO event to correct it.
    @Test func zeroWidthPanesReadAsExpanded() {
        #expect(TabBarCollapse.phase(visiblePaneWidths: [0], barWidth: 375) == .expanded)
        #expect(TabBarCollapse.phase(visiblePaneWidths: [0, 0], barWidth: 375) == .expanded)
    }

    /// Exactly the platter bound is still the platter: the midpoint itself reads as expanded, never minimized.
    @Test func theMidpointItselfReadsAsExpanded() {
        #expect(TabBarCollapse.phase(visiblePaneWidths: [187.5], barWidth: 375) == .expanded)
    }

    /// Mid-morph the capsule fades toward the opposite of the last settled state: a starting collapse fades out
    /// with the morph, a starting expand fades back in.
    @Test func theCapsuleFadesWithTheMorphInTheLeavingDirection() {
        #expect(TabBarCollapse.fadesOut(phase: .morphing, settled: .expanded))
        #expect(!TabBarCollapse.fadesOut(phase: .morphing, settled: .minimized))
        #expect(!TabBarCollapse.fadesOut(phase: .expanded, settled: .expanded))
        #expect(!TabBarCollapse.fadesOut(phase: .expanded, settled: .minimized))
        #expect(TabBarCollapse.fadesOut(phase: .minimized, settled: .minimized))
        #expect(TabBarCollapse.fadesOut(phase: .minimized, settled: .expanded))
    }

    /// The first settled read seeds the carried phase; a first read that lands mid-morph seeds minimized, so the
    /// capsule errs visible and the next settle corrects it — a hard-seeded expanded faded it invisible through a
    /// morph it attached into.
    @Test func theFirstReadSeedsTheSettledPhaseAndAMorphFirstReadErrsVisible() {
        #expect(TabBarCollapse.settle(current: .expanded, previous: nil) == .expanded)
        #expect(TabBarCollapse.settle(current: .minimized, previous: nil) == .minimized)
        let seeded = TabBarCollapse.settle(current: .morphing, previous: nil)
        #expect(seeded == .minimized)
        #expect(!TabBarCollapse.fadesOut(phase: .morphing, settled: seeded), "a mid-morph attach must err visible")
    }

    @Test func aMorphKeepsTheLastSettledPhaseAndASettleReplacesIt() {
        #expect(TabBarCollapse.settle(current: .morphing, previous: .expanded) == .expanded)
        #expect(TabBarCollapse.settle(current: .morphing, previous: .minimized) == .minimized)
        #expect(TabBarCollapse.settle(current: .expanded, previous: .minimized) == .expanded)
        #expect(TabBarCollapse.settle(current: .minimized, previous: .expanded) == .minimized)
    }
}
