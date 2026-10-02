import Foundation

/// Keeps the backend's device registry in step with this device, asks for the permission at the right moment and
/// opens the game behind a tapped reminder. The registration is repeated when the token or the user changed or the
/// last one is a day old, and undone before a sign-out while the Bearer is still there. Failures are logged, never
/// shown: a reminder that does not arrive is not worth a popup.
final class PushCoordinator: SessionObserver, PushOptIn {
    private(set) var registered: LastDeviceRegistration?
    /// The game of a notification tapped before the session was restored; opened once a user is known.
    private(set) var pendingEventID: String?
    private var isRegistering = false

    private let registrar: any PushRegistrar
    private let devices: any DeviceRepository
    private let identity: any IdentityProvider
    private let opener: EventOpener
    private let relay: PushEventRelay
    private let defaults: UserDefaults
    private let appVersion: AppVersion
    private let unregisterTimeout: Duration
    private let logger: any Logging
    private let now: () -> Date

    init(registrar: any PushRegistrar,
         devices: any DeviceRepository,
         identity: any IdentityProvider,
         opener: EventOpener,
         relay: PushEventRelay = .shared,
         defaults: UserDefaults,
         appVersion: AppVersion = .current(),
         unregisterTimeout: Duration = AppConfig.Push.unregisterTimeout,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.registrar = registrar
        self.devices = devices
        self.identity = identity
        self.opener = opener
        self.relay = relay
        self.defaults = defaults
        self.appVersion = appVersion
        self.unregisterTimeout = unregisterTimeout
        self.logger = logger
        self.now = now
        registered = Self.loadRegistration(from: defaults)
        relay.tapHandler = { [weak self] eventID in self?.handleTap(eventID: eventID) }
    }

    /// On every shell sync for a signed-in user: registers when the permission is granted and the backend is behind.
    func sync() async {
        guard let userID = identity.currentUserID else { return }
        guard await registrar.authorization() == .authorized else {
            logger.debug(.push, "Device not registered: notifications not authorized")
            return
        }
        await register(for: userID)
    }

    /// Asks once: when a signed-in user enters the app, and again after a join or create should the first ask not
    /// have happened; a grant registers the device at once. The system remembers the answer, so later calls are no-ops.
    func offerReminders() async {
        guard identity.currentUserID != nil, await registrar.authorization() == .notDetermined else { return }
        let granted = await registrar.requestAuthorization()
        logger.info(.push, granted ? "Notification permission granted" : "Notification permission declined")
        if granted { await sync() }
    }

    /// A tapped reminder: opened now when a user is signed in, else kept for `openPendingEvent()` after the restore.
    func handleTap(eventID: String) {
        logger.info(.push, "Notification tapped for event \(eventID)")
        pendingEventID = eventID
        guard identity.currentUserID != nil else { return }
        Task { await openPendingEvent() }
    }

    func openPendingEvent() async {
        guard let eventID = pendingEventID, identity.currentUserID != nil else { return }
        pendingEventID = nil
        await opener.open(eventID: eventID, from: "a notification")
    }

    /// The Bearer is still sent here, so the backend stops pushing to this device before the session is gone; a
    /// sign-out waits for it `unregisterTimeout` at most, since the row expires on its own and the backend takes the
    /// token from this account the moment another one registers it.
    func sessionWillEnd() async {
        guard let registered else { return }
        do {
            try await Self.within(unregisterTimeout) { [devices] in _ = try await devices.unregister(token: registered.token) }
            logger.info(.push, "Device unregistered for push")
        } catch {
            logger.warning(.push, "Device unregistration failed: \(error)")
        }
        store(nil)
    }

    func sessionDidEnd() {
        store(nil)
        pendingEventID = nil
    }

    private func register(for userID: String) async {
        guard !isRegistering else { return }
        isRegistering = true
        defer { isRegistering = false }
        do {
            let token = try await registrar.deviceToken()
            let interval = AppConfig.Push.reregisterInterval
            if let registered, registered.isCurrent(token: token, userID: userID, now: now(), within: interval) {
                logger.debug(.push, "Device registration still current")
                return
            }
            let payload = DeviceRegistrationPayload(token: token,
                                                    platform: AppConfig.Push.platform,
                                                    environment: .current,
                                                    appVersion: appVersion.headerValue)
            let registration = try await devices.register(payload)
            guard identity.isStillCaller(userID, orDrop: "Device registration", logger: logger) else { return }
            store(LastDeviceRegistration(token: registration.token, userID: userID, registeredAt: now()))
            logger.info(.push, "Device registered for push (\(registration.environment.rawValue))")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.push, "Device registration failed: \(error)")
        }
    }

    /// Runs `work` and gives up after `timeout` with `PushRegistrationError.timedOut`. The work is cancelled but not
    /// waited for (a task group would wait), so a request that ignores cancellation cannot hold the sign-out either.
    private static func within(_ timeout: Duration, _ work: @escaping () async throws -> Void) async throws {
        let worker = Task { try await work() }
        let first = FirstOutcome()
        let timer = Task {
            try? await Task.sleep(for: timeout)
            first.settle(.failure(PushRegistrationError.timedOut))
            worker.cancel()
        }
        Task {
            first.settle(await worker.result)
            timer.cancel()
        }
        try await first.outcome.get()
    }

    /// The first of two results wins; the second is dropped.
    private final class FirstOutcome {
        private var continuation: CheckedContinuation<Result<Void, any Error>, Never>?
        private var settled: Result<Void, any Error>?

        var outcome: Result<Void, any Error> {
            get async {
                if let settled { return settled }
                return await withCheckedContinuation { continuation = $0 }
            }
        }

        func settle(_ result: Result<Void, any Error>) {
            guard settled == nil else { return }
            settled = result
            continuation?.resume(returning: result)
            continuation = nil
        }
    }

    private func store(_ registration: LastDeviceRegistration?) {
        registered = registration
        let key = AppConfig.Push.lastRegistrationKey
        if let registration, let data = try? JSONEncoder().encode(registration) {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private static func loadRegistration(from defaults: UserDefaults) -> LastDeviceRegistration? {
        guard let data = defaults.data(forKey: AppConfig.Push.lastRegistrationKey) else { return nil }
        return try? JSONDecoder().decode(LastDeviceRegistration.self, from: data)
    }
}
