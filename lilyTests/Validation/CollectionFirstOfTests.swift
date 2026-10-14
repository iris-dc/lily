import Testing
@testable import lily

@MainActor
struct CollectionFirstOfTests {
    /// Stands in for a form's issues; the candidate order `name, place, time` is the section's field order.
    private enum Mark: Equatable {
        case name, place, time
    }

    /// The candidates' order wins over the collection's: a section's hint names its first field that is wrong.
    @Test func theFirstPresentIssueIsShownPerSection() {
        let present: [Mark] = [.time, .place]
        #expect(present.first(of: .name, .place, .time) == .place)
        #expect(present.first(of: .time, .place) == .time)
    }

    @Test func aCandidateTheCollectionLacksIsSkipped() {
        let present: [Mark] = [.time]
        #expect(present.first(of: .name, .place, .time) == .time)
    }

    @Test func noCandidatePresentShowsNothing() {
        let present: [Mark] = [.name]
        let shown = present.first(of: .place, .time)
        #expect(shown == nil)
    }

    @Test func noCandidatesShowNothing() {
        let present: [Mark] = [.name]
        let shown = present.first(of: [])
        #expect(shown == nil)
    }

    @Test func anEmptyCollectionShowsNothing() {
        let present: [Mark] = []
        let shown = present.first(of: .name)
        #expect(shown == nil)
    }
}
