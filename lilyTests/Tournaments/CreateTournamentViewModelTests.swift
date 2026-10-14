import Foundation
import Testing
@testable import lily

@MainActor
struct CreateTournamentViewModelTests {
    nonisolated private static let now = TournamentHarness.now
    private let harness = TournamentHarness()

    private func completeDraft(_ viewModel: CreateTournamentViewModel) {
        viewModel.draft.name = "Kickers Cup"
        viewModel.draft.locationName = "Görlitzer Park pitch"
        viewModel.draft.coordinate = AppConfig.Location.mockCenter
    }

    @Test func aNewDraftStartsOnTheHourAWeekAheadWithoutADeadline() {
        let viewModel = harness.makeCreateViewModel()
        let startsAt = viewModel.draft.startsAt
        let earliest = Self.now.addingTimeInterval(AppConfig.Tournaments.defaultStartOffset)
        #expect(startsAt >= earliest && startsAt < earliest.addingTimeInterval(3600))
        let components = Calendar.current.dateComponents([.minute, .second], from: startsAt)
        #expect(components.minute == 0 && components.second == 0)
        #expect(viewModel.draft.registrationClosesAt == nil)
        #expect(viewModel.draft.maxEntries == AppConfig.Tournaments.defaultMaxEntries)
        #expect(viewModel.issues == [.nameTooShort, .locationNameMissing, .coordinateMissing] && !viewModel.canSubmit)
        #expect(!viewModel.isLocked && viewModel.entriesRange == 2...64)
    }

    @Test func prepareTakesTheSpotAndTheEligibleGroups() async {
        await harness.loadGroups([.fixture(id: "open", role: .member),
                                  .fixture(id: "closed", membersCanCreateEvents: false, role: .member)])
        let location = MockLocationService(coordinate: AppConfig.Location.mockCenter)
        let viewModel = harness.makeCreateViewModel(locationService: location)

        await viewModel.prepare()

        #expect(viewModel.draft.coordinate == AppConfig.Location.mockCenter)
        #expect(viewModel.eligibleGroups.map(\.id) == ["open"] && viewModel.showsGroupRow && !viewModel.explainsNoEligibleGroups)
        #expect(harness.logger.messages(in: .location, at: .debug).count == 1)
    }

    @Test func aLockedGroupStampsTheDraft() async {
        let group = EventGroupRef(id: "g", name: "Kickers", visibility: .public, isDeleted: false)
        let viewModel = harness.makeCreateViewModel(lockedGroup: group)
        #expect(viewModel.draft.group == group && viewModel.showsGroupRow && viewModel.lockedGroup == group)
    }

    @Test func submitCreatesHandsOnAndLogs() async {
        let viewModel = harness.makeCreateViewModel()
        completeDraft(viewModel)
        #expect(viewModel.canSubmit)

        await viewModel.submit()

        #expect(viewModel.isDone && harness.sink.details.first?.tournament.name == "Kickers Cup")
        #expect(harness.repository.createdDrafts.map(\.clientId) == [viewModel.draft.clientId])
        #expect(harness.logs(.info).contains { $0.contains("Tournament created") && $0.contains("0 of 8 players") })
    }

    @Test func aSecondSubmitWhileOneIsInFlightIsDropped() async {
        harness.repository.holdsRequests = true
        let viewModel = harness.makeCreateViewModel()
        completeDraft(viewModel)

        let first = Task { await viewModel.submit() }
        await settle { viewModel.isSubmitting }
        await viewModel.submit()
        harness.repository.releaseRequests()
        await first.value

        #expect(harness.repository.createdDrafts.count == 1)
    }

    @Test(arguments: [AppError.tournamentCreationFailed, .network])
    func anUnknownOutcomeIsCheckedAgainstTheBackend(error: AppError) async {
        harness.repository.actionError = error
        let viewModel = harness.makeCreateViewModel()
        completeDraft(viewModel)
        let stored = Tournament.fixture(id: viewModel.draft.clientId, organizerUserId: TestFixtures.user.id)
        harness.repository.details[viewModel.draft.clientId] = .fixture(tournament: stored)

        await viewModel.submit()

        #expect(viewModel.isDone && harness.presentedError == nil && harness.sink.details.count == 1)
        #expect(harness.logs(.info).contains { $0.contains("Create landed") })
    }

    @Test func aFailureWithNothingLandedReachesThePopup() async {
        harness.repository.actionError = AppError.tournamentLimit
        let viewModel = harness.makeCreateViewModel()
        completeDraft(viewModel)

        await viewModel.submit()

        #expect(!viewModel.isDone && harness.presentedError == .tournamentLimit && harness.repository.fetchedIDs.isEmpty)
        #expect(harness.logs(.error)
            .filter { $0.hasPrefix("Create failed for tournament \(viewModel.draft.clientId):") }.count == 1)
    }

    @Test func anotherOrganisersTournamentUnderTheIdIsNotOurs() async {
        harness.repository.actionError = AppError.network
        let viewModel = harness.makeCreateViewModel()
        completeDraft(viewModel)
        let stored = Tournament.fixture(id: viewModel.draft.clientId, organizerUserId: "other")
        harness.repository.details[viewModel.draft.clientId] = .fixture(tournament: stored)

        await viewModel.submit()

        #expect(!viewModel.isDone && harness.presentedError == .network)
    }

    /// Nothing under the client id is the check's answer: the create did not land, the popup shows the create's own
    /// failure, and the lookup leaves a debug line, never a warning.
    @Test func aCreateThatDidNotLandIsReportedWithoutAWarning() async {
        harness.repository.actionError = AppError.network
        let viewModel = harness.makeCreateViewModel()
        completeDraft(viewModel)

        await viewModel.submit()

        #expect(!viewModel.isDone && harness.presentedError == .network)
        #expect(harness.repository.fetchedIDs == [viewModel.draft.clientId])
        #expect(harness.logs(.warning).isEmpty)
        #expect(harness.logs(.debug).contains { $0.contains("did not land") })
    }

    /// A lookup that fails for another reason settles nothing: the create's failure stands and a warning says so.
    @Test func aFailedLookupKeepsTheFailureWithAWarning() async {
        harness.repository.actionError = AppError.network
        harness.repository.detailError = AppError.tournamentsUnavailable
        let viewModel = harness.makeCreateViewModel()
        completeDraft(viewModel)

        await viewModel.submit()

        #expect(!viewModel.isDone && harness.presentedError == .network)
        #expect(harness.logs(.warning)
            .filter { $0.contains("Could not check whether tournament \(viewModel.draft.clientId) landed") }.count == 1)
    }

    /// The reminder prompt follows the create: once, after the sheet is done and the tournament was handed on.
    @Test func aTournamentCreateOffersRemindersOnceAfterTheTournamentWasHandedOn() async {
        let spy = SpyPushOptIn()
        let viewModel = harness.makeCreateViewModel(pushOptIn: spy)
        completeDraft(viewModel)
        var handedOnAtOffer = false
        spy.onOffer = { handedOnAtOffer = viewModel.isDone && !harness.sink.details.isEmpty }

        await viewModel.submit()

        #expect(spy.offerCount == 1)
        #expect(handedOnAtOffer)
    }

    /// A create that landed although its answer was lost earns the prompt like a direct answer.
    @Test func aTournamentCreateThatLandedDespiteAFailureOffersRemindersOnce() async {
        harness.repository.actionError = AppError.network
        let spy = SpyPushOptIn()
        let viewModel = harness.makeCreateViewModel(pushOptIn: spy)
        completeDraft(viewModel)
        let stored = Tournament.fixture(id: viewModel.draft.clientId, organizerUserId: TestFixtures.user.id)
        harness.repository.details[viewModel.draft.clientId] = .fixture(tournament: stored)

        await viewModel.submit()

        #expect(viewModel.isDone)
        #expect(spy.offerCount == 1)
    }

    /// Nothing landed, so the popup is what the user sees and there is nothing to be reminded of.
    @Test func aFailedTournamentCreateNeverOffersReminders() async {
        harness.repository.actionError = AppError.tournamentLimit
        let spy = SpyPushOptIn()
        let viewModel = harness.makeCreateViewModel(pushOptIn: spy)
        completeDraft(viewModel)

        await viewModel.submit()

        #expect(harness.presentedError == .tournamentLimit)
        #expect(spy.offerCount == 0)
    }

    /// A start an hour ahead puts "a day before" behind the clock, so the proposal is the injected now (the wall clock
    /// would answer the day before); a start three days ahead gets the full lead.
    @Test func theDeadlineProposalUsesTheInjectedClock() {
        let viewModel = harness.makeCreateViewModel()
        viewModel.draft.startsAt = Self.now.addingTimeInterval(3600)
        #expect(viewModel.proposedDeadline() == Self.now)

        viewModel.draft.startsAt = Self.now.addingTimeInterval(3 * 24 * 3600)
        let lead = AppConfig.Tournaments.defaultDeadlineLead
        #expect(viewModel.proposedDeadline() == viewModel.draft.startsAt.addingTimeInterval(-lead))
    }

    @Test func aNewTournamentOffersItsStructure() {
        let viewModel = harness.makeCreateViewModel()
        #expect(viewModel.allowsStructureChanges)
    }
}

@MainActor
struct EditTournamentViewModelTests {
    private let harness = TournamentHarness()

    /// Starts a day after the harness clock, so the editing rules find nothing wrong with the start.
    private let ahead = TournamentHarness.now.addingTimeInterval(86_400)

    @Test func anEditSavesOnlyOnceSomethingChangedAndKeepsTheLockRules() async {
        let tournament = Tournament.fixture(id: "t", entryCount: 4, startsAt: ahead, organizerUserId: TestFixtures.user.id)
        harness.repository.details["t"] = .fixture(tournament: tournament)
        let viewModel = harness.makeEditViewModel(for: tournament)
        #expect(!viewModel.hasChanges && !viewModel.canSubmit && !viewModel.isLocked && viewModel.entriesRange == 4...12)
        #expect(viewModel.lockedGroup == nil && !viewModel.showsGroupRow && viewModel.eligibleGroups.isEmpty)

        viewModel.draft.name = "Wednesday Table Tennis"
        #expect(viewModel.canSubmit)
        await viewModel.submit()

        #expect(viewModel.isDone && harness.sink.details.first?.tournament.name == "Wednesday Table Tennis")
        #expect(harness.repository.updatedDrafts.first?.id == "t")
        #expect(harness.logs(.info).contains { $0.contains("updated") })
    }

    /// A tournament under way has its start behind it; the schedule is sent as stored, so a rename still goes through.
    @Test func aStartedTournamentCanStillBeRenamed() async {
        let started = Tournament.fixture(id: "t",
                                         status: .inProgress,
                                         entryCount: 4,
                                         startsAt: TournamentHarness.now.addingTimeInterval(-3600),
                                         organizerUserId: TestFixtures.user.id)
        harness.repository.details["t"] = .fixture(tournament: started)
        let viewModel = harness.makeEditViewModel(for: started)
        #expect(viewModel.isLocked && viewModel.issues.isEmpty && !viewModel.canSubmit, "nothing changed yet")

        viewModel.draft.name = "Renamed Cup"
        #expect(viewModel.canSubmit)
        await viewModel.submit()

        #expect(viewModel.isDone && harness.sink.details.last?.tournament.name == "Renamed Cup")
    }

    @Test func aStartedTournamentIsLocked() {
        let viewModel = harness.makeEditViewModel(for: .fixture(status: .inProgress))
        #expect(viewModel.isLocked)
    }

    /// The type, format, team size and visibility are fixed once the tournament exists, whatever its phase.
    @Test func anEditNeverOffersTheStructure() {
        let open = harness.makeEditViewModel(for: .fixture())
        let started = harness.makeEditViewModel(for: .fixture(status: .inProgress))
        #expect(!open.allowsStructureChanges && !started.allowsStructureChanges)
    }

    @Test func anEditsDeadlineProposalUsesTheInjectedClock() {
        let viewModel = harness.makeEditViewModel(for: .fixture(startsAt: TournamentHarness.now.addingTimeInterval(3600)))
        #expect(viewModel.proposedDeadline() == TournamentHarness.now)
    }

    @Test func aTryAgainIsRepeatedAndAFailureReported() async {
        let tournament = Tournament.fixture(id: "t", startsAt: ahead, organizerUserId: TestFixtures.user.id)
        harness.repository.details["t"] = .fixture(tournament: tournament)
        harness.repository.transientErrors = [.tryAgain]
        let viewModel = harness.makeEditViewModel(for: tournament)
        viewModel.draft.name = "Renamed"
        await viewModel.submit()
        #expect(viewModel.isDone && harness.repository.updatedDrafts.count == 2)

        harness.repository.actionError = AppError.tournamentLocked
        let second = harness.makeEditViewModel(for: tournament)
        second.draft.name = "Again"
        await second.submit()
        #expect(!second.isDone && harness.presentedError == .tournamentLocked)
    }
}
