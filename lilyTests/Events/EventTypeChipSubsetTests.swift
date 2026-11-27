import Foundation
import Testing
@testable import lily

/// The compact type picker rule the edit form and the filter share: the head of the list plus the selection while
/// collapsed, the whole list once expanded, and a search that reaches every type whatever the expansion — one pure
/// function (`EventTypeChipSubset.visible`) over the shared `String.matchesSearch`, tested as one. The filter hands
/// it a set; the edit form's single selection goes through the delegating overload.
struct EventTypeChipSubsetTests {
    /// The top three is the product decision, so the number is pinned, not just read back from the constant.
    private let topOfTheList = Array(EventType.known.prefix(3))

    @Test func collapsedShowsTheHeadOfTheListAndTheExpander() {
        #expect(DesignTokens.Layout.collapsedTypeChipCount == 3)
        let visible = EventTypeChipSubset.visible(matching: "", expanded: false, selected: .football)
        #expect(visible.types == [.football, .basketball, .tennis])
        #expect(visible.types == topOfTheList)
        #expect(visible.showsExpander)
        #expect(!visible.showsCollapser && visible.rest.isEmpty)
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

    /// Unfolding never reorders the head: the rest is appended after it in the same flow, every known type exactly
    /// once across the two lists, Show less trailing, so no chip relocates when the fold swaps.
    @Test func expandedKeepsTheHeadAndAppendsTheRest() {
        let collapsed = EventTypeChipSubset.visible(matching: "", expanded: false, selected: .yoga)
        let visible = EventTypeChipSubset.visible(matching: "", expanded: true, selected: .yoga)
        #expect(visible.types == collapsed.types && visible.types == topOfTheList + [.yoga])
        #expect(visible.rest == EventType.known.filter { !visible.types.contains($0) }, "the rest keeps the known order")
        #expect((visible.types + visible.rest).sorted { $0.wireName < $1.wireName }
                    == EventType.known.sorted { $0.wireName < $1.wireName })
        #expect(!visible.showsExpander)
        #expect(visible.showsCollapser, "Show less trails the rest, so the wall folds back")
    }

    @Test func aSearchReachesEveryTypeRegardlessOfExpansion() {
        let collapsed = EventTypeChipSubset.visible(matching: "yoga", expanded: false, selected: .football)
        #expect(collapsed.types == [.yoga])
        #expect(!collapsed.showsExpander && !collapsed.showsCollapser, "a search needs neither control")
        #expect(collapsed == EventTypeChipSubset.visible(matching: "yoga", expanded: true, selected: .football))
    }

    @Test func aSearchNoNameContainsShowsNothingAndNoExpander() {
        let visible = EventTypeChipSubset.visible(matching: "zzz", expanded: false, selected: .football)
        #expect(visible.types.isEmpty)
        #expect(!visible.showsExpander)
    }

    /// The filter's multi-select: every chosen known type joins the head, in the known list's order, not the pick's.
    @Test func aSelectedSetJoinsTheHeadInTheKnownOrder() {
        let visible = EventTypeChipSubset.visible(matching: "",
                                                  expanded: false,
                                                  selected: Set([EventType.yoga, .padel, .football]))
        #expect(visible.types == topOfTheList + [.padel, .yoga])
        #expect(visible.showsExpander)

        let unknownOnly = EventTypeChipSubset.visible(matching: "",
                                                      expanded: false,
                                                      selected: Set([EventType.unknown("cricket")]))
        #expect(unknownOnly.types == topOfTheList, "an unknown selection is never offered")

        let searching = EventTypeChipSubset.visible(matching: "yoga",
                                                    expanded: false,
                                                    selected: Set([EventType.football]))
        #expect(searching.types == [.yoga] && !searching.showsExpander, "a query ignores the selection")
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
