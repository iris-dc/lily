import Foundation
@testable import lily

@MainActor
final class SpyPasteboard: Pasteboard {
    private(set) var copied: [String] = []

    func copy(_ text: String) {
        copied.append(text)
    }
}

/// Counts calls, for closures a harness hands out before it is fully initialised.
@MainActor
final class CallCounter {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

/// What a view model handed on through `onChange`, `onCreated` or `onJoined`.
@MainActor
final class GroupSink {
    private(set) var groups: [SportGroup] = []

    func record(_ group: SportGroup) {
        groups.append(group)
    }
}

/// The collaborators every groups view model shares, over fakes: one identity, one store, one reporter whose terms
/// requests are counted. Collaborators are created in the body: a main-actor default argument would run off the actor.
@MainActor
final class GroupHarness {
    let repository = FakeGroupRepository()
    let invites = FakeInviteRepository()
    let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    let changes = ChangeTracker()
    let logger = SpyLogger()
    let recorder = SpyInteractionRecorder()
    let pasteboard = SpyPasteboard()
    let navigation = AppNavigation()
    let sink = GroupSink()
    let errorCenter: ErrorCenter
    let store: MyGroupsStore
    let reporter: GroupErrorReporter
    private let termsRequests = CallCounter()

    var termsRequiredCount: Int { termsRequests.count }
    var changed: [SportGroup] { sink.groups }
    var presentedError: AppError? { errorCenter.current?.error }

    init() {
        errorCenter = ErrorCenter(logger: logger)
        store = MyGroupsStore(repository: repository,
                              identity: identity,
                              changes: changes,
                              errorCenter: errorCenter,
                              logger: logger)
        let termsRequests = self.termsRequests
        reporter = GroupErrorReporter(errorCenter: errorCenter) { termsRequests.increment() }
    }

    func logs(_ level: LogLevel? = nil) -> [String] {
        logger.messages(in: .groups, at: level)
    }
}
