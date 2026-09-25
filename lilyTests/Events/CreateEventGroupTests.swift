import Foundation
import Testing
@testable import lily

/// Hosting a game in a group: the form's Group row follows the caller's groups, a sheet opened from a group is
/// locked to it, and the group travels with the draft.
@MainActor
struct CreateEventGroupTests {
    private let kickers = SportGroup.fixture(id: "kickers", name: "Kreuzberg Kickers", role: .member)
    private let padel = SportGroup.fixture(id: "padel", name: "Sunday Padel Crew", visibility: .private, role: .owner)
    /// A member of a group whose members may not create games: never offered.
    private let runners = SportGroup.fixture(id: "runners", name: "Runners", membersCanCreateEvents: false, role: .member)

    @Test func aFreshDraftHasNoGroupAndHidesTheRowForAUserWithoutGroups() async {
        let harness = CreateEventHarness()

        await harness.viewModel.prepare()

        #expect(harness.viewModel.draft.group == nil)
        #expect(harness.viewModel.lockedGroup == nil)
        #expect(harness.viewModel.eligibleGroups.isEmpty)
        #expect(!harness.viewModel.showsGroupRow)
    }

    /// The picker offers the groups the caller may host in, read from the store without a request of its own.
    @Test func prepareOffersTheGroupsTheCallerMayCreateGamesIn() async {
        let harness = CreateEventHarness()
        await harness.loadGroups([kickers, runners, padel])
        let requestsBefore = harness.groupRepository.requestedScopes.count

        await harness.viewModel.prepare()

        #expect(harness.viewModel.eligibleGroups == [kickers.ref, padel.ref])
        #expect(harness.viewModel.showsGroupRow)
        #expect(harness.viewModel.draft.group == nil, "the choice is the host's; nothing is preselected")
        #expect(harness.groupRepository.requestedScopes.count == requestsBefore)
    }

    @Test func aLockedGroupIsStampedOnTheDraftAndShowsTheRow() async {
        let harness = CreateEventHarness(lockedGroup: kickers.ref)

        #expect(harness.viewModel.lockedGroup == kickers.ref)
        #expect(harness.viewModel.draft.group == kickers.ref)
        #expect(harness.viewModel.showsGroupRow, "the row shows the preset even before any group is loaded")
    }

    @Test func theCreatedGameCarriesTheGroupAndTheLogNamesItsId() async throws {
        let harness = CreateEventHarness(lockedGroup: kickers.ref)
        harness.completeDraft()

        await harness.viewModel.submit()

        let created = try #require(harness.viewModel.createdEvent)
        #expect(created.group == kickers.ref)
        #expect(harness.repository.createdDrafts.first?.group == kickers.ref)
        let line = try #require(harness.logger.messages(in: .events, at: .info).first { $0.contains("Event created") })
        #expect(line.contains("in group kickers"))
        #expect(!line.contains("Kreuzberg"), "names never reach a log line")
    }

    @Test func aGameOfItsOwnLogsNoGroup() async throws {
        let harness = CreateEventHarness()
        harness.completeDraft()

        await harness.viewModel.submit()

        let line = try #require(harness.logger.messages(in: .events, at: .info).first { $0.contains("Event created") })
        #expect(!line.contains("group"))
    }
}
