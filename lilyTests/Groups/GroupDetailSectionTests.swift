import Testing
@testable import lily

/// Which segments the group detail's picker offers, by the caller's access to the group and the tournaments flag.
struct GroupDetailSectionTests {
    private static let publicGroup = SportGroup.fixture()
    private static let privateGroup = SportGroup.fixture(visibility: .private)

    private func sections(of group: SportGroup, userID: String?, tournamentsEnabled: Bool) -> [GroupDetailSection] {
        GroupDetailSection.available(for: GroupAccess(group: group, userID: userID),
                                     in: group,
                                     tournamentsEnabled: tournamentsEnabled)
    }

    /// The backend lists a public group's tournaments to anyone, so a guest reaches the Kickers Cup from the group.
    @Test func guestsSeeTheTournamentsSegmentOfAPublicGroup() {
        #expect(sections(of: Self.publicGroup, userID: nil, tournamentsEnabled: true) == [.events, .tournaments])
    }

    @Test func anOutsiderOfAPublicGroupSeesEverySegment() {
        #expect(sections(of: Self.publicGroup, userID: "u", tournamentsEnabled: true) == GroupDetailSection.allCases)
    }

    @Test func aMemberOfAPrivateGroupSeesEverySegment() {
        let group = SportGroup.fixture(visibility: .private, role: .member)
        #expect(sections(of: group, userID: "u", tournamentsEnabled: true) == GroupDetailSection.allCases)
    }

    @Test func aGuestOfAPrivateGroupSeesEventsOnly() {
        #expect(sections(of: Self.privateGroup, userID: nil, tournamentsEnabled: true) == [.events])
    }

    /// A private group's tournaments answer 404 to an outsider, so the segment is not offered.
    @Test func anOutsiderOfAPrivateGroupGetsNoTournamentsAndNoRoster() {
        #expect(sections(of: Self.privateGroup, userID: "u", tournamentsEnabled: true) == [.events])
    }

    @Test func withTheFlagOffNobodyGetsTournaments() {
        let group = SportGroup.fixture(role: .member)
        #expect(sections(of: group, userID: "u", tournamentsEnabled: false) == [.events, .members])
    }

    /// The view shows the picker for more than one segment; a guest of a private group has one and gets none.
    @Test func onlyOneSegmentMeansNoPicker() {
        #expect(sections(of: Self.privateGroup, userID: nil, tournamentsEnabled: true).count == 1)
    }
}
