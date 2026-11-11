import Foundation
import Testing
@testable import lily

/// What keeps a group draft from being sent, judged at the boundaries of `AppConfig.Groups`.
struct GroupDraftTests {
    private static let limits = AppConfig.Groups.self

    private static func text(_ count: Int) -> String {
        String(repeating: "x", count: count)
    }

    @Test func aNewDraftHasTheDefaultsAndAsksForAName() {
        let draft = GroupDraft()

        #expect(draft.name.isEmpty && draft.description.isEmpty && draft.type == nil)
        #expect(draft.visibility == .public && draft.membersCanCreateEvents && draft.membersCanInvite)
        #expect(draft.locationName.isEmpty && draft.coordinate == nil && draft.location == nil)
        #expect(draft.issues == [.nameTooShort, .locationNameMissing] && !draft.isValid)
        #expect(UUID(uuidString: draft.clientId) != nil && draft.clientId == draft.clientId.lowercased())
        #expect(GroupDraft().clientId != draft.clientId)
    }

    @Test func nameLengthIsJudgedTrimmedAtBothBounds() {
        var draft = GroupDraft.fixture()
        draft.name = "  " + Self.text(Self.limits.nameLength.lowerBound) + "\n"
        #expect(draft.issues.isEmpty)

        draft.name = Self.text(Self.limits.nameLength.lowerBound - 1) + "   "
        #expect(draft.issues == [.nameTooShort])

        draft.name = Self.text(Self.limits.nameLength.upperBound)
        #expect(draft.issues.isEmpty)

        draft.name = Self.text(Self.limits.nameLength.upperBound + 1)
        #expect(draft.issues == [.nameTooLong])
    }

    /// The backend counts UTF-16 units, so an emoji counts two here as well.
    @Test func lengthsAreCountedInUTF16UnitsLikeTheBackend() {
        var draft = GroupDraft.fixture()
        draft.name = String(repeating: "😀", count: Self.limits.nameLength.upperBound / 2 + 1)
        draft.description = String(repeating: "😀", count: Self.limits.descriptionMaxLength / 2 + 1)

        #expect(draft.issues == [.nameTooLong, .descriptionTooLong])
    }

    @Test func aBlankDescriptionIsAbsentAndALongOneRefused() {
        var draft = GroupDraft.fixture()
        draft.description = " \n "
        #expect(draft.trimmedDescription == nil && draft.issues.isEmpty)

        draft.description = Self.text(Self.limits.descriptionMaxLength)
        #expect(draft.issues.isEmpty)

        draft.description = Self.text(Self.limits.descriptionMaxLength + 1)
        #expect(draft.issues == [.descriptionTooLong])
    }

    /// What the mock repository and the test fake answer for a create: owned and joined by the caller, one member.
    @Test func makeGroupIsOwnedByTheCallerWithTheDraftsDetails() {
        var draft = GroupDraft.fixture()
        draft.name = " Sunday Padel Crew "
        draft.description = " Two courts "
        draft.visibility = .private
        draft.type = .padel
        draft.membersCanInvite = false
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let group = draft.makeGroup(ownerName: "Jo", now: now)

        #expect(group.id == draft.clientId && group.name == "Sunday Padel Crew" && group.description == "Two courts")
        #expect(group.visibility == .private && group.type == .padel && group.ownerName == "Jo")
        #expect(group.memberCount == 1 && group.maxMembers == Self.limits.maxMembers && group.channelEpoch == 1)
        #expect(group.membersCanCreateEvents && !group.membersCanInvite)
        #expect(group.createdAt == now && group.lastMessageAt == nil && !group.isDeleted)
        #expect(group.role == .owner && group.membership?.joinedAt == now)
    }

    @Test func editingAGroupStartsFromItsFields() {
        let place = EventLocation(name: "Tempelhofer Feld", coordinate: .aroundMockCenter(lat: -0.7, lon: -0.3))
        var group = SportGroup.fixture(id: "g1",
                                       name: "Runners",
                                       visibility: .private,
                                       type: .running,
                                       membersCanInvite: false,
                                       location: place)
        group = group.updating(with: { var draft = GroupDraft(editing: group); draft.description = "Loops"; return draft }())

        let draft = GroupDraft(editing: group)

        #expect(draft.clientId == "g1" && draft.name == "Runners" && draft.description == "Loops")
        #expect(draft.visibility == .private && draft.type == .running)
        #expect(draft.locationName == "Tempelhofer Feld" && draft.coordinate == place.coordinate && draft.location == place)
        #expect(draft.membersCanCreateEvents && !draft.membersCanInvite && draft.isValid)
        #expect(group.location == place, "an edit keeps the place it started from")
    }

    /// A public group is found by where it plays, so it must name a place; a private one is reached by invite.
    @Test func aPublicGroupNeedsAPlaceAPrivateOneMayHaveNone() {
        var draft = GroupDraft.fixture()
        draft.locationName = "  "
        #expect(draft.issues == [.locationNameMissing] && draft.location == nil)

        draft.visibility = .private
        #expect(draft.issues.isEmpty && draft.location == nil, "no place, nothing sent")

        draft.coordinate = nil
        #expect(draft.issues.isEmpty, "a spot alone without a name is nothing to send either")
    }

    /// A named place needs its spot, whatever the visibility, and stays under the backend's name limit.
    @Test func aNamedPlaceNeedsItsSpotAndStaysUnderTheLimit() {
        var draft = GroupDraft.fixture(coordinate: nil)
        #expect(draft.issues == [.coordinateMissing] && draft.location == nil)

        draft.visibility = .private
        #expect(draft.issues == [.coordinateMissing], "a private group that names a place must set it too")

        draft.coordinate = AppConfig.Location.mockCenter
        draft.locationName = " " + Self.text(Self.limits.locationNameMaxLength) + " "
        #expect(draft.issues.isEmpty && draft.location?.name.count == Self.limits.locationNameMaxLength)

        draft.locationName = Self.text(Self.limits.locationNameMaxLength + 1)
        #expect(draft.issues == [.locationNameTooLong])
    }

    /// The place travels into the stored group as the payload sends it: trimmed name, the chosen spot.
    @Test func makeGroupAndUpdatingCarryThePlace() {
        var draft = GroupDraft.fixture()
        draft.locationName = " Görlitzer Park "
        let place = EventLocation(name: "Görlitzer Park", coordinate: AppConfig.Location.mockCenter)

        #expect(draft.location == place)
        #expect(draft.makeGroup(ownerName: "Jo", now: .now).location == place)
        #expect(SportGroup.fixture().updating(with: draft).location == place)

        draft.locationName = ""
        draft.visibility = .private
        #expect(SportGroup.fixture(location: place).updating(with: draft).location == nil, "an edit may clear the place")
    }

    @Test func issueCopyNamesTheLimits() {
        #expect(AppBranding.Groups.Create.message(for: .nameTooShort).contains("\(Self.limits.nameLength.lowerBound)"))
        #expect(AppBranding.Groups.Create.message(for: .nameTooLong).contains("\(Self.limits.nameLength.upperBound)"))
        #expect(AppBranding.Groups.Create.message(for: .descriptionTooLong).contains("\(Self.limits.descriptionMaxLength)"))
        #expect(AppBranding.Groups.Create.message(for: .locationNameTooLong).contains("\(Self.limits.locationNameMaxLength)"))
        #expect(AppBranding.Groups.Create.message(for: .coordinateMissing) == AppBranding.Events.Create.pickOnMap)
    }
    /// The shared place bookkeeping (`PlacePickingDraft`): when suggestions are asked, what a tapped suggestion and
    /// a map pick change, and that an edited group starts with its spot picked.
    @Test func thePlaceBookkeepingMirrorsTheEventDrafts() {
        var draft = GroupDraft()
        draft.locationName = " G "
        #expect(draft.placeSuggestionQuery == nil)
        draft.locationName = " Görlitzer "
        #expect(draft.placeSuggestionQuery == "Görlitzer")

        let park = PlaceSuggestion(title: "Görlitzer Park", subtitle: "Berlin", coordinate: AppConfig.Location.mockCenter)
        draft.apply(park)
        #expect(draft.locationName == "Görlitzer Park" && draft.coordinate == park.coordinate)
        #expect(draft.suggestedName == "Görlitzer Park" && !draft.spotPickedOnMap)
        #expect(draft.placeSuggestionQuery == nil, "the name a suggestion just set is not asked about")

        draft.pickSpot(Coordinate(latitude: 54.35, longitude: 18.65))
        #expect(draft.spotPickedOnMap && draft.suggestedName == nil)
    }

    @Test func anEditedGroupStartsWithItsSpotPicked() {
        let edited = GroupDraft(editing: .fixture())
        #expect(edited.spotPickedOnMap && edited.suggestedName == nil)
    }
}
