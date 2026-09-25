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
        #expect(draft.issues == [.nameTooShort] && !draft.isValid)
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
        var group = SportGroup.fixture(id: "g1", name: "Runners", visibility: .private, type: .running, membersCanInvite: false)
        group = group.updating(with: { var draft = GroupDraft(editing: group); draft.description = "Loops"; return draft }())

        let draft = GroupDraft(editing: group)

        #expect(draft.clientId == "g1" && draft.name == "Runners" && draft.description == "Loops")
        #expect(draft.visibility == .private && draft.type == .running)
        #expect(draft.membersCanCreateEvents && !draft.membersCanInvite && draft.isValid)
    }

    @Test func issueCopyNamesTheLimits() {
        #expect(AppBranding.Groups.Create.message(for: .nameTooShort).contains("\(Self.limits.nameLength.lowerBound)"))
        #expect(AppBranding.Groups.Create.message(for: .nameTooLong).contains("\(Self.limits.nameLength.upperBound)"))
        #expect(AppBranding.Groups.Create.message(for: .descriptionTooLong).contains("\(Self.limits.descriptionMaxLength)"))
    }
}
