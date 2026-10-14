import Foundation

/// Keeps the backend's device registry in step with this device, asks for the permission at the right moment and
/// opens the game or the match behind a tapped reminder. The registration is repeated when the token, the user or the
/// app's language changed or the last one is a day old, and undone before a sign-out while the Bearer is still there.
/// Failures are logged, never shown: a reminder that does not arrive is not worth a popup.
final class PushCoordinator: SessionObserver, PushOptIn {
    private(set) var registered: LastDeviceRegistration?
    /// A notification tapped before the session was restored; opened once a user is known.
    private(set) var pendingTap: PushTap?
    /// A registration in flight; a `sync()` made meanwhile joins it, and a sign-out waits for it before it unregisters.
    private var registration: Task<Void, Never>?

    private let registrar: any PushRegistrar
    private let devices: any DeviceRepository
    private let identity: any IdentityProvider
    private let opener: EventOpener
    private let tournamentOpener: TournamentOpener
    private let relay: PushEventRelay
    private let defaults: UserDefaults
    private let appVersion: AppVersion
    /// The language the app shows, read at each registration so the backend's reminder follows a change.
    private let languageCode: () -> String
    private let unregisterTimeout: Duration
    private let sleep: Sleep
    private let logger: any Logging
    private let now: () -> Date

    init(registrar: any PushRegistrar,
         devices: any DeviceRepository,
         identity: any IdentityProvider,
         opener: EventOpener,
         tournamentOpener: TournamentOpener,
         relay: PushEventRelay = .shared,
         defaults: UserDefaults,
         appVersion: AppVersion = .current(),
         languageCode: @escaping () -> String,
         unregisterTimeout: Duration = AppConfig.Push.unregisterTimeout,
         sleep: @escaping Sleep = systemSleep,
         logger: any Logging,
         now: @escaping () -> Date = { .now }) {
        self.registrar = registrar
        self.devices = devices
        self.identity = identity
        self.opener = opener
        self.tournamentOpener = tournamentOpener
        self.relay = relay
        self.defaults = defaults
        self.appVersion = appVersion
        self.languageCode = languageCode
        self.unregisterTimeout = unregisterTimeout
        self.sleep = sleep
        self.logger = logger
        self.now = now
        registered = Self.loadRegistration(from: defaults)
        relay.tapHandler = { [weak self] tap in self?.handleTap(tap) }
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

    /// A tapped reminder: opened now when a user is signed in, else kept for `openPendingTap()` after the restore.
    func handleTap(_ tap: PushTap) {
        logger.info(.push, "Notification tapped for \(tap.logName)")
        pendingTap = tap
        guard identity.currentUserID != nil else { return }
        Task { await openPendingTap() }
    }

    func openPendingTap() async {
        guard let tap = pendingTap, identity.currentUserID != nil else { return }
        pendingTap = nil
        switch tap {
        case .event(let eventID):
            await opener.open(eventID: eventID, from: "a notification")
        case .match(let tournamentID, let matchID):
            await tournamentOpener.open(tournamentID: tournamentID, matchID: matchID, from: "a notification")
        }
    }

    /// Runs while the Bearer is still sent, so the backend stops pushing to this device before the session is gone. A
    /// registration in flight is awaited first, or its PUT could leave the device registered to the departed account.
    /// The whole waits `unregisterTimeout` at most: the row expires on its own, and another account registering the
    /// token takes it over.
    func sessionWillEnd() async {
        guard registered != nil || registration != nil else { return }
        let tokenBefore = registered?.token
        do {
            try await Deadline.within(unregisterTimeout, sleep: sleep, orThrow: PushRegistrationError.timedOut) { [self] in
                // Awaited, never cancelled: a cancelled PUT may have landed, and nothing here would know its token.
                await registration?.value
                try await unregister(tokens: [tokenBefore, registered?.token].compactMap { $0 })
            }
        } catch {
            logger.warning(.push, "Device unregistration failed: \(error)")
        }
        store(nil)
    }

    /// Every token this device may still hold on the backend: the one known before the sign-out and the one a
    /// registration that landed meanwhile stored (two when the token rotated).
    private func unregister(tokens: [String]) async throws {
        for token in Set(tokens) { _ = try await devices.unregister(token: token) }
        if !tokens.isEmpty { logger.info(.push, "Device unregistered for push") }
    }

    func sessionDidEnd() {
        store(nil)
        pendingTap = nil
    }

    private func register(for userID: String) async {
        if let registration { return await registration.value }
        let task = Task { await performRegistration(for: userID) }
        registration = task
        await task.value
        registration = nil
    }

    private func performRegistration(for userID: String) async {
        do {
            let token = try await registrar.deviceToken()
            let locale = languageCode()
            let interval = AppConfig.Push.reregisterInterval
            if let registered,
               registered.isCurrent(token: token, userID: userID, locale: locale, now: now(), within: interval) {
                logger.debug(.push, "Device registration still current")
                return
            }
            let payload = DeviceRegistrationPayload(token: token,
                                                    platform: AppConfig.Push.platform,
                                                    environment: .current,
                                                    appVersion: appVersion.headerValue,
                                                    locale: locale)
            let registration = try await devices.register(payload)
            guard identity.isStillCaller(userID, orDrop: "Device registration", logger: logger) else { return }
            store(LastDeviceRegistration(token: registration.token, userID: userID, locale: locale, registeredAt: now()))
            logger.info(.push, "Device registered for push (\(registration.environment.rawValue), \(locale))")
        } catch {
            guard !AppError.isCancellation(error) else { return }
            logger.warning(.push, "Device registration failed: \(error)")
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
