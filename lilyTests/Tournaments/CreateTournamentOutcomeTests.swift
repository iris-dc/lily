import Foundation
import Testing
@testable import lily

/// What a reused id keeps: the PUT after `TOURNAMENT_ID_REUSED` carries no format, team size, visibility or group, so
/// the first tap's structure stands and each kept field is a warning, ids only. Split from
/// `CreateTournamentViewModelTests` for the file limit.
@MainActor
struct CreateTournamentOutcomeTests {
    private let harness = TournamentHarness()

    private func makeRepeatedCreate() -> CreateTournamentViewModel {
        harness.repository.transientErrors = [.createIdReused]
        let viewModel = harness.makeCreateViewModel()
        viewModel.draft.name = "Kickers Cup"
        viewModel.draft.locationName = "Görlitzer Park pitch"
        viewModel.draft.coordinate = AppConfig.Location.mockCenter
        // The spot counts as picked, so the round-5 choice rule is satisfied like a user's own pick.
        viewModel.draft.spotPickedOnMap = true
        return viewModel
    }

    @Test func aReusedIdKeepsTheFirstTapsStructureAndWarnsPerField() async throws {
        let viewModel = makeRepeatedCreate()
        viewModel.draft.format = .roundRobin
        viewModel.draft.teamSize = 2
        viewModel.draft.visibility = .private
        let stored = Tournament.fixture(id: viewModel.draft.clientId,
                                        format: .singleElimination,
                                        visibility: .public,
                                        teamSize: 1,
                                        organizerUserId: TestFixtures.user.id)
        harness.repository.details[viewModel.draft.clientId] = .fixture(tournament: stored)

        await viewModel.submit()

        let created = try #require(viewModel.created).tournament
        #expect(created.format == .singleElimination && created.teamSize == 1 && created.visibility == .public)
        #expect(harness.presentedError == nil)
        let kept = harness.logs(.warning).mentioning([created.id, "keeps its", "the draft named another"])
        #expect(kept.count == 3 && !kept.contains { $0.contains("group") })
        #expect(["format", "team size", "visibility"].allSatisfy { field in kept.contains { $0.contains("keeps its \(field)") } })
    }

    /// With a group named, the visibility is the group's to decide: only the group is reported kept.
    @Test func aReusedIdKeepsTheFirstTapsGroupAndWarnsForTheGroupAlone() async throws {
        let viewModel = makeRepeatedCreate()
        viewModel.draft.format = .roundRobin
        viewModel.draft.group = EventGroupRef(id: "g2", name: "Runners", visibility: .private, isDeleted: false)
        let stored = Tournament.fixture(id: viewModel.draft.clientId, organizerUserId: TestFixtures.user.id)
        harness.repository.details[viewModel.draft.clientId] = .fixture(tournament: stored)

        await viewModel.submit()

        let created = try #require(viewModel.created).tournament
        #expect(created.group == nil && harness.presentedError == nil)
        #expect(harness.logs(.warning).mentioning([created.id, "keeps its group", "the draft named another"]).count == 1)
        #expect(harness.logs(.warning).mentioning(["keeps its"]).count == 1)
    }

    /// A repeat whose edit changed nothing the PUT leaves out logs nothing kept.
    @Test func aReusedIdWithTheSameStructureWarnsAboutNothing() async throws {
        let viewModel = makeRepeatedCreate()
        viewModel.draft.format = .roundRobin
        let stored = Tournament.fixture(id: viewModel.draft.clientId,
                                        name: "Kickers Cup (old)",
                                        organizerUserId: TestFixtures.user.id)
        harness.repository.details[viewModel.draft.clientId] = .fixture(tournament: stored)

        await viewModel.submit()

        #expect(viewModel.isDone && harness.presentedError == nil)
        #expect(harness.logs(.warning).mentioning(["keeps its"]).isEmpty)
    }
}
