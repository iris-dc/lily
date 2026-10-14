import Foundation
@testable import lily

/// The collaborators every tournament view model shares, over fakes: one identity, one fake repository, one reporter
/// whose terms requests are counted. Collaborators are created in the body: a main-actor default argument would run
/// off the actor.
@MainActor
final class TournamentHarness {
    /// 08:25:07 UTC, so "the next full hour" is unambiguous. `nonisolated`: read by `@Test(arguments:)` off the actor.
    nonisolated static let now = Date(timeIntervalSince1970: 1_800_000_000 + 25 * 60 + 7)

    let repository = FakeTournamentRepository()
    let groupRepository = FakeGroupRepository()
    let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    let changes = ChangeTracker()
    /// The store's own tracker; `changes` is the one the tournament view models bump.
    let groupChanges = ChangeTracker()
    let logger = SpyLogger()
    let recorder = SpyInteractionRecorder()
    let navigation = AppNavigation()
    let errorCenter: ErrorCenter
    let groups: MyGroupsStore
    private let terms: TermsCountingReporter
    private let recordedTournaments = Recorded<Tournament>()
    private let recordedDetails = Recorded<TournamentDetail>()

    var reporter: GroupErrorReporter { terms.reporter }
    var termsRequiredCount: Int { terms.termsRequiredCount }
    var presentedError: AppError? { errorCenter.current?.error }
    /// What the view models handed on: every `Tournament` from a detail's `onChange`, every `TournamentDetail` from a
    /// create's `onCreated` or an edit's `onChange`.
    var sink: (tournaments: [Tournament], details: [TournamentDetail]) {
        (recordedTournaments.values, recordedDetails.values)
    }

    init() {
        errorCenter = ErrorCenter(logger: logger)
        groups = MyGroupsStore(repository: groupRepository,
                               identity: identity,
                               changes: groupChanges,
                               errorCenter: errorCenter,
                               logger: logger)
        terms = TermsCountingReporter(errorCenter: errorCenter)
        repository.organizerUserID = TestFixtures.user.id
    }

    func logs(_ level: LogLevel? = nil) -> [String] {
        logger.messages(in: .tournaments, at: level)
    }

    /// `now` defaults to the harness's fixed clock; a cooldown test hands in one it can advance.
    func makeListViewModel(scope: TournamentScope,
                           locationService: (any LocationService)? = nil,
                           now: (() -> Date)? = nil) -> TournamentListViewModel {
        TournamentListViewModel(scope: scope,
                                repository: repository,
                                identity: identity,
                                locationService: locationService ?? MockLocationService(),
                                changes: changes,
                                errorCenter: errorCenter,
                                logger: logger,
                                now: now ?? { Self.now })
    }

    /// `pushOptIn` is created in the body when not given: a main-actor default argument would run off the actor. The
    /// `onChange` records the tournament (`sink.tournaments`) and then does what the stack's root would: the given closure
    /// (Home hands its Mine list's `replace`), else the tracker bump every other root hands over through
    /// `GroupDestinations`.
    func makeDetailViewModel(for destination: TournamentDestination,
                             pushOptIn: (any PushOptIn)? = nil,
                             onChange: (@MainActor (Tournament) -> Void)? = nil) -> TournamentDetailViewModel {
        let recorded = recordedTournaments
        let changes = self.changes
        return TournamentDetailViewModel(destination: destination,
                                         repository: repository,
                                         groupRepository: groupRepository,
                                         myGroups: groups,
                                         identity: identity,
                                         navigation: navigation,
                                         changes: changes,
                                         reporter: reporter,
                                         recorder: recorder,
                                         logger: logger,
                                         tryAgainDelay: .zero,
                                         now: { Self.now },
                                         pushOptIn: pushOptIn ?? NoPushOptIn(),
                                         onChange: { tournament in
                                             recorded.record(tournament)
                                             if let onChange { onChange(tournament) } else { changes.recordChange() }
                                         })
    }

    /// A detail view model with its tournament loaded: the fixture detail is stored under the destination's id first.
    func loadedDetailViewModel(_ tournament: Tournament,
                               entries: [TournamentEntry] = [.fixture()],
                               for destination: TournamentDestination,
                               pushOptIn: (any PushOptIn)? = nil) async -> TournamentDetailViewModel {
        repository.details[destination.id] = .fixture(tournament: tournament, entries: entries)
        let viewModel = makeDetailViewModel(for: destination, pushOptIn: pushOptIn)
        await viewModel.load()
        return viewModel
    }

    /// `pushOptIn` is created in the body when not given: a main-actor default argument would run off the actor.
    func makeCreateViewModel(locationService: (any LocationService)? = nil,
                             lockedGroup: EventGroupRef? = nil,
                             pushOptIn: (any PushOptIn)? = nil) -> CreateTournamentViewModel {
        CreateTournamentViewModel(repository: repository,
                                  identity: identity,
                                  locationService: locationService ?? MockLocationService(),
                                  groups: groups,
                                  reporter: reporter,
                                  logger: logger,
                                  now: { Self.now },
                                  pushOptIn: pushOptIn ?? NoPushOptIn(),
                                  lockedGroup: lockedGroup,
                                  onCreated: recordedDetails.record)
    }

    func makeEditViewModel(for tournament: Tournament) -> EditTournamentViewModel {
        EditTournamentViewModel(tournament: tournament,
                                repository: repository,
                                reporter: reporter,
                                logger: logger,
                                tryAgainDelay: .zero,
                                now: { Self.now },
                                onChange: recordedDetails.record)
    }

    /// Puts groups into the store the way the sign-in load does.
    func loadGroups(_ groups: [SportGroup]) async {
        groupRepository.result = .success(groups)
        await self.groups.reload()
    }
}
