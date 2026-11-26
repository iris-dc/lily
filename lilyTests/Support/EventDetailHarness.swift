import Foundation
@testable import lily

/// An `EventDetailViewModel` over fakes with a fixed clock and a zero retry pause, so no test waits on a clock;
/// `replaced` records what it handed to the list. `pushOptIn` is built in the body when not given: a main-actor
/// default argument would run off the actor.
@MainActor
final class EventDetailHarness {
    /// `nonisolated`: read by `@Test(arguments:)` and stored-property initialisers off the actor. Fixed well before
    /// the fixtures' wall-clock starts, so a default fixture game reads as upcoming (participation judges the start).
    nonisolated static let now = Date(timeIntervalSince1970: 1_700_000_000)

    let repository = FakeEventRepository()
    let groupRepository = FakeGroupRepository()
    let identity: FakeIdentityProvider
    let recorder = SpyInteractionRecorder()
    let logger = SpyLogger()
    let errorCenter: ErrorCenter
    /// The group-changes tracker behind Mine; the detail's room syncs write through the store.
    let groupChanges = ChangeTracker()
    let groups: MyGroupsStore
    let viewModel: EventDetailViewModel
    private let changed = Recorded<SportEvent>()

    var replaced: [SportEvent] { changed.values }

    init(event: SportEvent, userID: String? = TestFixtures.user.id, pushOptIn: (any PushOptIn)? = nil) {
        identity = FakeIdentityProvider(currentUserID: userID)
        errorCenter = ErrorCenter(logger: logger)
        repository.result = .success([event])
        groups = MyGroupsStore(repository: groupRepository,
                               identity: identity,
                               changes: groupChanges,
                               errorCenter: errorCenter,
                               logger: logger)
        viewModel = EventDetailViewModel(event: event,
                                         repository: repository,
                                         identity: identity,
                                         myGroups: groups,
                                         groupRepository: groupRepository,
                                         errorCenter: errorCenter,
                                         recorder: recorder,
                                         logger: logger,
                                         tryAgainDelay: .zero,
                                         now: { Self.now },
                                         pushOptIn: pushOptIn ?? NoPushOptIn(),
                                         onChange: changed.record)
    }
}
