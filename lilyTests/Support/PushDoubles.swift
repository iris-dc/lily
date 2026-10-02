import Foundation
import Testing
@testable import lily

/// A scripted registrar: the permission as the test sets it, a token or a refusal, and counts of what was asked.
@MainActor
final class FakePushRegistrar: PushRegistrar {
    var status: PushAuthorization = .authorized
    /// What the prompt answers; granting also moves `status`.
    var grants = true
    var token = "cd".repeated(32)
    var tokenError: PushRegistrationError?
    private(set) var requestCount = 0
    private(set) var tokenRequestCount = 0

    func authorization() async -> PushAuthorization {
        status
    }

    func requestAuthorization() async -> Bool {
        requestCount += 1
        if grants { status = .authorized } else { status = .denied }
        return grants
    }

    func deviceToken() async throws -> String {
        tokenRequestCount += 1
        if let tokenError { throw tokenError }
        return token
    }
}

/// Records registrations and removals; fails them on demand, or holds a removal until the test lets it go.
@MainActor
final class FakeDeviceRepository: DeviceRepository {
    var registerError: AppError?
    var unregisterError: AppError?
    /// While true, `unregister` records the call and then suspends until `releaseRequests()`.
    var holdsRequests: Bool {
        get { hold.isEnabled }
        set { hold.isEnabled = newValue }
    }
    private let hold = RequestHold()
    private(set) var registrations: [DeviceRegistrationPayload] = []
    private(set) var unregisteredTokens: [String] = []

    func register(_ payload: DeviceRegistrationPayload) async throws -> DeviceRegistration {
        if let registerError { throw registerError }
        registrations.append(payload)
        return DeviceRegistration(token: payload.token.lowercased(), environment: payload.environment, registeredAt: .now)
    }

    func unregister(token: String) async throws -> DeviceRemoval {
        if let unregisterError { throw unregisterError }
        unregisteredTokens.append(token)
        await hold.wait()
        try Task.checkCancellation()
        return DeviceRemoval(token: token, removed: true)
    }

    func releaseRequests() {
        hold.release()
    }
}

/// The test's clock, a box so the coordinator's `now` closure captures it and not the harness.
@MainActor
final class DateBox {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }
}

/// A coordinator over fakes, with its own relay and defaults suite so nothing leaks between tests.
@MainActor
final class PushHarness {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    let registrar = FakePushRegistrar()
    let devices = FakeDeviceRepository()
    let events = FakeEventRepository()
    let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    let navigation = AppNavigation()
    let relay = PushEventRelay()
    let defaults = makeTestDefaults()
    let logger = SpyLogger()
    let clock = DateBox(PushHarness.now)
    let errorCenter: ErrorCenter
    /// Built with the harness, so the relay's tap handler is set before a test taps.
    private(set) lazy var coordinator: PushCoordinator = makeCoordinator()

    init() {
        errorCenter = ErrorCenter(logger: logger)
        _ = coordinator
    }

    /// Another coordinator over the same defaults, as a relaunch would build; a relay, repository or sign-out timeout
    /// of its own on request.
    func makeCoordinator(relay: PushEventRelay? = nil,
                         devices: (any DeviceRepository)? = nil,
                         unregisterTimeout: Duration = AppConfig.Push.unregisterTimeout) -> PushCoordinator {
        PushCoordinator(registrar: registrar,
                        devices: devices ?? self.devices,
                        identity: identity,
                        opener: makeOpener(),
                        relay: relay ?? self.relay,
                        defaults: defaults,
                        appVersion: AppVersion(marketing: "1.0", build: "42"),
                        unregisterTimeout: unregisterTimeout,
                        logger: logger,
                        now: { [clock] in clock.now })
    }

    func makeOpener() -> EventOpener {
        EventOpener(events: events,
                    navigation: navigation,
                    reporter: GroupErrorReporter(errorCenter: errorCenter) {},
                    logger: logger)
    }

    func logs(_ level: LogLevel? = nil) -> [String] {
        logger.messages(in: .push, at: level)
    }
}

private extension String {
    func repeated(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}
