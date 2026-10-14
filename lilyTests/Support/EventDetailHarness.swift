import Foundation
@testable import lily

/// An `EventDetailViewModel` over fakes with a fixed clock and a zero retry pause, so no test waits on a clock;
/// `replaced` records what it handed to the list. `pushOptIn` is built in the body when not given: a main-actor
/// default argument would run off the actor.
@MainActor
final class EventDetailHarness {
    /// `nonisolated`: read by `@Test(arguments:)` and stored-property initialisers off the actor.
    nonisolated static let now = Date(timeIntervalSince1970: 1_800_000_000)

    let repository = FakeEventRepository()
    let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    let recorder = SpyInteractionRecorder()
    let logger = SpyLogger()
    let errorCenter: ErrorCenter
    let viewModel: EventDetailViewModel
    private let changed = Recorded<SportEvent>()

    var replaced: [SportEvent] { changed.values }

    init(event: SportEvent, pushOptIn: (any PushOptIn)? = nil) {
        errorCenter = ErrorCenter(logger: logger)
        repository.result = .success([event])
        viewModel = EventDetailViewModel(event: event,
                                         repository: repository,
                                         identity: identity,
                                         errorCenter: errorCenter,
                                         recorder: recorder,
                                         logger: logger,
                                         tryAgainDelay: .zero,
                                         now: { Self.now },
                                         pushOptIn: pushOptIn ?? NoPushOptIn(),
                                         onChange: changed.record)
    }
}
