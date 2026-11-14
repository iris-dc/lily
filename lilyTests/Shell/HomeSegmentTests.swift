import Testing
import UIKit
@testable import lily

/// The segmented Home's model: which segments the flags offer, and the copy and wizard seed each one carries.
/// The per-segment pane states live in the shared `ListState`, pinned in `ListStateTests`.
@MainActor
struct HomeSegmentTests {
    @Test func theOfferKeepsDeclarationOrderAndAlwaysCarriesEvents() {
        #expect(HomeSegment.allCases == [.events, .tournaments, .groups])
        #expect(HomeSegment.offered(groups: true, tournaments: true) == [.events, .tournaments, .groups])
        #expect(HomeSegment.offered(groups: false, tournaments: false) == [.events])
        #expect(HomeSegment.offered(groups: true, tournaments: false) == [.events, .groups])
        #expect(HomeSegment.offered(groups: false, tournaments: true) == [.events, .tournaments])
        #expect(HomeSegment.offered().contains(.groups) == AppConfig.FeatureFlags.groups)
        #expect(HomeSegment.offered().contains(.tournaments) == AppConfig.FeatureFlags.tournaments)
    }

    @Test(arguments: [
        (HomeSegment.events, CreationKind.event),
        (.tournaments, .tournament),
        (.groups, .group)
    ])
    func theCreateButtonSeedsTheWizardWithTheSegmentsKind(segment: HomeSegment, kind: CreationKind) {
        #expect(segment.creationKind == kind)
    }

    /// Every segment carries its own words: an empty line would be a catalog key gone missing, and two segments
    /// sharing one would mislabel the picker, the create button or the empty and failed hints.
    @Test func everySegmentCarriesItsOwnCopy() {
        let copies: [KeyPath<HomeSegment, String>] = [\.title, \.createTitle, \.emptyTitle, \.emptyMessage, \.failedMessage]
        for copy in copies {
            let lines = HomeSegment.allCases.map { $0[keyPath: copy] }
            #expect(lines.allSatisfy { !$0.isEmpty })
            #expect(Set(lines).count == HomeSegment.allCases.count)
        }
    }

    /// The count line shows the number through the catalog's plural key and reads differently per segment.
    @Test func theCountLineCarriesTheCountAndNamesItsSegment() {
        let lines = HomeSegment.allCases.map { $0.countLine(2) }
        #expect(lines.allSatisfy { $0.contains("2") })
        #expect(Set(lines).count == HomeSegment.allCases.count)
    }

    /// A misspelt SF Symbol draws nothing, so the empty hints' glyphs are checked here instead of by eye.
    @Test func everySegmentsGlyphExists() {
        for segment in HomeSegment.allCases {
            #expect(UIImage(systemName: segment.symbolName) != nil, "\(segment)")
        }
    }
}
