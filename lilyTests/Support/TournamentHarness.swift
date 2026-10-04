import Foundation
@testable import lily

/// What a tournament view model handed on through `onChange` or `onCreated`.
@MainActor
final class TournamentSink {
    private(set) var tournaments: [Tournament] = []
    private(set) var details: [TournamentDetail] = []

    func record(_ tournament: Tournament) {
        tournaments.append(tournament)
    }

    func record(_ detail: TournamentDetail) {
        details.append(detail)
    }
}

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
    let logger = SpyLogger()
    let recorder = SpyInteractionRecorder()
    let navigation = AppNavigation()
    let sink = TournamentSink()
    let errorCenter: ErrorCenter
    let groups: MyGroupsStore
    let reporter: GroupErrorReporter
    private let termsRequests = CallCounter()

    var termsRequiredCount: Int { termsRequests.count }
    var presentedError: AppError? { errorCenter.current?.error }

    init() {
        errorCenter = ErrorCenter(logger: logger)
        groups = MyGroupsStore(repository: groupRepository,
                               identity: identity,
                               changes: ChangeTracker(),
                               errorCenter: errorCenter,
                               logger: logger)
        let termsRequests = self.termsRequests
        reporter = GroupErrorReporter(errorCenter: errorCenter) { termsRequests.increment() }
        repository.organizerUserID = TestFixtures.user.id
    }

    func logs(_ level: LogLevel? = nil) -> [String] {
        logger.messages(in: .tournaments, at: level)
    }

    func makeListViewModel(scope: TournamentScope, locationService: (any LocationService)? = nil) -> TournamentListViewModel {
        TournamentListViewModel(scope: scope,
                                repository: repository,
                                identity: identity,
                                locationService: locationService ?? MockLocationService(),
                                changes: changes,
                                errorCenter: errorCenter,
                                logger: logger,
                                now: { Self.now })
    }

    /// `pushOptIn` is created in the body when not given: a main-actor default argument would run off the actor. The
    /// `onChange` records the tournament and bumps the tracker, as `GroupDestinations` does in the app.
    func makeDetailViewModel(for destination: TournamentDestination,
                             pushOptIn: (any PushOptIn)? = nil) -> TournamentDetailViewModel {
        let sink = self.sink
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
                                             sink.record(tournament)
                                             changes.recordChange()
                                         })
    }

    func makeCreateViewModel(locationService: (any LocationService)? = nil,
                             lockedGroup: EventGroupRef? = nil) -> CreateTournamentViewModel {
        CreateTournamentViewModel(repository: repository,
                                  identity: identity,
                                  locationService: locationService ?? MockLocationService(),
                                  groups: groups,
                                  reporter: reporter,
                                  logger: logger,
                                  now: { Self.now },
                                  lockedGroup: lockedGroup,
                                  onCreated: sink.record)
    }

    func makeEditViewModel(for tournament: Tournament) -> EditTournamentViewModel {
        EditTournamentViewModel(tournament: tournament,
                                repository: repository,
                                reporter: reporter,
                                logger: logger,
                                tryAgainDelay: .zero,
                                now: { Self.now },
                                onChange: sink.record)
    }

    /// Puts groups into the store the way the sign-in load does.
    func loadGroups(_ groups: [SportGroup]) async {
        groupRepository.result = .success(groups)
        await self.groups.reload()
    }
}
