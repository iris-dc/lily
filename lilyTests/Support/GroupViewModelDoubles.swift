import Foundation
@testable import lily

@MainActor
final class SpyPasteboard: Pasteboard {
    private(set) var copied: [String] = []

    func copy(_ text: String) {
        copied.append(text)
    }
}

/// Counts calls made through a closure a struct suite hands out, since the suite cannot write back into itself.
@MainActor
final class CallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

/// A `GroupErrorReporter` whose requests for the terms sheet are counted; the harnesses share it.
@MainActor
final class TermsCountingReporter {
    private(set) var termsRequiredCount = 0
    private(set) lazy var reporter = GroupErrorReporter(errorCenter: errorCenter) { [weak self] in
        self?.termsRequiredCount += 1
    }
    private let errorCenter: ErrorCenter

    init(errorCenter: ErrorCenter) {
        self.errorCenter = errorCenter
    }
}

/// The collaborators every groups and inbox view model shares, over fakes: one identity, one store, one inbox, one
/// reporter whose terms requests are counted. Collaborators are created in the body: a main-actor default argument
/// would run off the actor.
@MainActor
final class GroupHarness {
    let repository = FakeGroupRepository()
    let invites = FakeInviteRepository()
    let inboxRepository = FakeInboxRepository()
    let events = FakeEventRepository()
    let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    /// Answers no position until a test sets `result`, so Discover sends none by default.
    let location = FakeLocationService()
    let changes = ChangeTracker()
    let tournamentChanges = ChangeTracker()
    let logger = SpyLogger()
    let recorder = SpyInteractionRecorder()
    let pasteboard = SpyPasteboard()
    let navigation = AppNavigation()
    let sink = Recorded<SportGroup>()
    let errorCenter: ErrorCenter
    let store: MyGroupsStore
    let inbox: InboxStore
    private let terms: TermsCountingReporter

    var reporter: GroupErrorReporter { terms.reporter }
    var termsRequiredCount: Int { terms.termsRequiredCount }
    var changed: [SportGroup] { sink.values }
    var presentedError: AppError? { errorCenter.current?.error }

    init() {
        errorCenter = ErrorCenter(logger: logger)
        store = MyGroupsStore(repository: repository,
                              identity: identity,
                              changes: changes,
                              errorCenter: errorCenter,
                              logger: logger)
        inbox = InboxStore(repository: inboxRepository, identity: identity, errorCenter: errorCenter, logger: logger)
        terms = TermsCountingReporter(errorCenter: errorCenter)
    }

    func logs(_ level: LogLevel? = nil) -> [String] {
        logger.messages(in: .groups, at: level)
    }

    func inboxLogs(_ level: LogLevel? = nil) -> [String] {
        logger.messages(in: .inbox, at: level)
    }

    func tournamentLogs(_ level: LogLevel? = nil) -> [String] {
        logger.messages(in: .tournaments, at: level)
    }

    func makeInboxViewModel() -> InboxViewModel {
        InboxViewModel(store: inbox,
                       repository: inboxRepository,
                       opener: EventOpener(events: events, navigation: navigation, reporter: reporter, logger: logger),
                       myGroups: store,
                       tournamentChanges: tournamentChanges,
                       navigation: navigation,
                       reporter: reporter,
                       logger: logger,
                       tryAgainDelay: .zero)
    }

    /// A view model over an inbox holding `items`, opened once: the page queued, the fake told what it holds, `appear()` run.
    func openInbox(_ items: [InboxItem]) async -> InboxViewModel {
        inboxRepository.pages = [.fixture(items)]
        inboxRepository.items = items
        let viewModel = makeInboxViewModel()
        await viewModel.appear()
        return viewModel
    }

    /// The repository stores `group`, so writes and refetches answer from it until a test changes `result`.
    func makeGroupDetailViewModel(_ group: SportGroup,
                                  context: GroupDetailContext = .standalone,
                                  now: Date = Date(timeIntervalSince1970: 1_800_000_000)) -> GroupDetailViewModel {
        repository.result = .success([group])
        return GroupDetailViewModel(group: group,
                                    context: context,
                                    repository: repository,
                                    identity: identity,
                                    store: store,
                                    reporter: reporter,
                                    recorder: recorder,
                                    logger: logger,
                                    tryAgainDelay: .zero,
                                    now: { now })
    }

    /// The roster of `group`, stored in the repository like the detail's; what it hands on lands in `changed`.
    func makeMembersViewModel(group: SportGroup) -> MembersViewModel {
        repository.result = .success([group])
        return MembersViewModel(group: group,
                                repository: repository,
                                identity: identity,
                                reporter: reporter,
                                logger: logger,
                                tryAgainDelay: .zero,
                                onChange: sink.record)
    }

    func makeInvitePeopleViewModel(for group: SportGroup) -> InvitePeopleViewModel {
        makeInvitePeopleViewModel(for: .group(id: group.id))
    }

    func makeInvitePeopleViewModel(for target: InviteTarget) -> InvitePeopleViewModel {
        InvitePeopleViewModel(target: target, repository: invites, reporter: reporter, logger: logger, tryAgainDelay: .zero)
    }

    /// Discover searches the repository and reloads on `changes`; the position comes from `location`.
    func makeDiscoverGroupsViewModel() -> DiscoverGroupsViewModel {
        DiscoverGroupsViewModel(changes: changes,
                                repository: repository,
                                identity: identity,
                                locationService: location,
                                errorCenter: errorCenter,
                                recorder: recorder,
                                logger: logger)
    }
}
