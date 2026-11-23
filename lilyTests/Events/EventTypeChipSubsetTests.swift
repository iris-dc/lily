import Foundation
import Testing
@testable import lily

/// The edit form's compact type picker rule: the head of the list plus the selection while collapsed, the whole list
/// once expanded, and a search that reaches every type whatever the expansion — one pure function
/// (`EventTypeChipSubset.visible`) over the shared `String.matchesSearch`, tested as one.
struct EventTypeChipSubsetTests {
    /// The top three is the product decision, so the number is pinned, not just read back from the constant.
    private let topOfTheList = Array(EventType.known.prefix(3))

    @Test func collapsedShowsTheHeadOfTheListAndTheExpander() {
        #expect(DesignTokens.Layout.collapsedTypeChipCount == 3)
        let visible = EventTypeChipSubset.visible(matching: "", expanded: false, selected: .football)
        #expect(visible.types == [.football, .basketball, .tennis])
        #expect(visible.types == topOfTheList)
        #expect(visible.showsExpander)
    }

    @Test func aSelectionBeyondTheHeadIsAppendedSoTheChoiceIsNeverHidden() {
        let visible = EventTypeChipSubset.visible(matching: "", expanded: false, selected: .yoga)
        #expect(visible.types == topOfTheList + [.yoga])
        #expect(visible.showsExpander)
    }

    /// A type from a newer backend draws as Other yet is never offered in a chip or picker; the compact picker
    /// keeps that rule rather than appending a selected unknown.
    @Test func anUnknownSelectionIsNeverOffered() {
        let visible = EventTypeChipSubset.visible(matching: "", expanded: false, selected: .unknown("cricket"))
        #expect(visible.types == topOfTheList)
        #expect(visible.showsExpander)
    }

    @Test func expandedShowsEveryKnownTypeWithNoExpander() {
        let visible = EventTypeChipSubset.visible(matching: "", expanded: true, selected: .yoga)
        #expect(visible.types == EventType.known)
        #expect(!visible.showsExpander)
    }

    @Test func aSearchReachesEveryTypeRegardlessOfExpansion() {
        let collapsed = EventTypeChipSubset.visible(matching: "yoga", expanded: false, selected: .football)
        #expect(collapsed.types == [.yoga])
        #expect(!collapsed.showsExpander)
        #expect(collapsed == EventTypeChipSubset.visible(matching: "yoga", expanded: true, selected: .football))
    }

    @Test func aSearchNoNameContainsShowsNothingAndNoExpander() {
        let visible = EventTypeChipSubset.visible(matching: "zzz", expanded: false, selected: .football)
        #expect(visible.types.isEmpty)
        #expect(!visible.showsExpander)
    }

    @Test func theMatchIsCaseAndDiacriticInsensitiveAndABlankQueryCollapses() {
        #expect("Fútbol".matchesSearch("futbol"))
        #expect("Table tennis".matchesSearch(" TENNIS "))
        #expect(!"Tennis".matchesSearch("yoga"))
        let blank = EventTypeChipSubset.visible(matching: "   ", expanded: false, selected: .football)
        #expect(blank.types == topOfTheList)
        #expect(blank.showsExpander)
    }
}
