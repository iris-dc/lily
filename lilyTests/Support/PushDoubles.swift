import Foundation
import Testing
@testable import lily

/// A scripted registrar: the permission as the test sets it, a token or a refusal, and counts of what was asked.
@MainActor
final class FakePushRegistrar: PushRegistrar {
    var status: PushAuthorization = .authorized
    /// What the prompt answers; granting also moves `status`.
    var grants = true
    var token = String(repeating: "cd", count: 32)
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

/// Records registrations and removals and fails them on demand. While `holdsRequests`, `register` and `unregister`
/// record the call and then suspend until `releaseRequests()`.
@MainActor
final class FakeDeviceRepository: DeviceRepository, HoldsRequests {
    var registerError: AppError?
    var unregisterError: AppError?
    let hold = RequestHold()
    private(set) var registrations: [DeviceRegistrationPayload] = []
    private(set) var unregisteredTokens: [String] = []

    func register(_ payload: DeviceRegistrationPayload) async throws -> DeviceRegistration {
        if let registerError { throw registerError }
        registrations.append(payload)
        try await hold.waitOrThrow()
        return DeviceRegistration(token: payload.token.lowercased(), environment: payload.environment, registeredAt: .now)
    }

    func unregister(token: String) async throws -> DeviceRemoval {
        if let unregisterError { throw unregisterError }
        unregisteredTokens.append(token)
        try await hold.waitOrThrow()
        return DeviceRemoval(token: token, removed: true)
    }
}

/// A coordinator over fakes, with its own relay and defaults suite so nothing leaks between tests.
@MainActor
final class PushHarness {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    let registrar = FakePushRegistrar()
    let devices = FakeDeviceRepository()
    let events = FakeEventRepository()
    let tournaments = FakeTournamentRepository()
    let identity = FakeIdentityProvider(currentUserID: TestFixtures.user.id)
    let navigation = AppNavigation()
    /// The pause every coordinator and relay built here waits on, held and released by the test.
    let sleep: HeldSleep
    let relay: PushEventRelay
    let defaults = makeTestDefaults()
    let logger = SpyLogger()
    let clock = DateClock(PushHarness.now)
    /// What the coordinator registers as the device's language; a test changes it to see a registration repeated.
    var languageCode = "en"
    let errorCenter: ErrorCenter
    /// Built with the harness, so the relay's tap handler is set before a test taps.
    private(set) lazy var coordinator: PushCoordinator = makeCoordinator()

    init() {
        let sleep = HeldSleep()
        self.sleep = sleep
        relay = PushEventRelay { try await sleep.sleep(for: $0) }
        errorCenter = ErrorCenter(logger: logger)
        _ = coordinator
    }

    /// `sleep` as the seam the coordinator and the relay take.
    var pause: Sleep {
        { [sleep] in try await sleep.sleep(for: $0) }
    }

    /// Another coordinator over the same defaults, as a relaunch would build; a relay or repository of its own on
    /// request.
    func makeCoordinator(relay: PushEventRelay? = nil, devices: (any DeviceRepository)? = nil) -> PushCoordinator {
        PushCoordinator(registrar: registrar,
                        devices: devices ?? self.devices,
                        identity: identity,
                        opener: makeOpener(),
                        tournamentOpener: makeTournamentOpener(),
                        relay: relay ?? self.relay,
                        defaults: defaults,
                        appVersion: AppVersion(marketing: "1.0", build: "42"),
                        languageCode: { [weak self] in self?.languageCode ?? "en" },
                        sleep: pause,
                        logger: logger,
                        now: { [clock] in clock.now })
    }

    func makeOpener() -> EventOpener {
        EventOpener(events: events,
                    navigation: navigation,
                    reporter: GroupErrorReporter(errorCenter: errorCenter) {},
                    logger: logger)
    }

    func makeTournamentOpener() -> TournamentOpener {
        TournamentOpener(tournaments: tournaments,
                         navigation: navigation,
                         reporter: GroupErrorReporter(errorCenter: errorCenter) {},
                         logger: logger)
    }

    func logs(_ level: LogLevel? = nil) -> [String] {
        logger.messages(in: .push, at: level)
    }

    /// Counts the `.push` lines at `level` containing `fragment`; a key event is logged exactly once.
    func logged(_ fragment: String, at level: LogLevel) -> Int {
        logs(level).filter { $0.contains(fragment) }.count
    }
}

/// Counts how often a view model offered the reminder permission. `onOffer` runs first, so a test can read the view
/// model's state at the moment of the offer.
@MainActor
final class SpyPushOptIn: PushOptIn {
    var onOffer: () -> Void = {}
    private(set) var offerCount = 0

    func offerReminders() async {
        onOffer()
        offerCount += 1
    }
}
