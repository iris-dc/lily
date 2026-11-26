import Foundation

/// The push collaborators, built as one value so `AppDependencies` gains a single stored property: the coordinator
/// over the registrar and device repository the data layer chose (system or mock) and the game opener it shares with
/// the inbox; the tournament opener behind a match reminder's tap is the coordinator's alone.
struct PushDependencies {
    let registrar: any PushRegistrar
    let devices: any DeviceRepository
    let opener: EventOpener
    /// The per-device mutes the coordinator registers and Settings' Notifications screen flips.
    let notificationPreferences: NotificationPreferences
    let coordinator: PushCoordinator

    init(registrar: any PushRegistrar,
         devices: any DeviceRepository,
         events: any EventRepository,
         tournaments: any TournamentRepository,
         identity: any IdentityProvider,
         navigation: AppNavigation,
         errorCenter: ErrorCenter,
         defaults: UserDefaults,
         languageCode: @escaping () -> String,
         logger: any Logging) {
        let opener = EventOpener(events: events,
                                 navigation: navigation,
                                 errorCenter: errorCenter,
                                 logger: logger)
        let tournamentOpener = TournamentOpener(tournaments: tournaments,
                                                navigation: navigation,
                                                errorCenter: errorCenter,
                                                logger: logger)
        self.opener = opener
        self.registrar = registrar
        self.devices = devices
        let preferences = NotificationPreferences(defaults: defaults)
        notificationPreferences = preferences
        coordinator = PushCoordinator(registrar: registrar,
                                      devices: devices,
                                      preferences: preferences,
                                      identity: identity,
                                      opener: opener,
                                      tournamentOpener: tournamentOpener,
                                      defaults: defaults,
                                      languageCode: languageCode,
                                      logger: logger)
    }
}

extension AppDependencies {
    var pushCoordinator: PushCoordinator { push.coordinator }
    var eventOpener: EventOpener { push.opener }
    var notificationPreferences: NotificationPreferences { push.notificationPreferences }

    /// Settings' Notifications screen over the registrar's status, this device's mutes and the coordinator's sync.
    func makeNotificationsViewModel() -> NotificationsViewModel {
        NotificationsViewModel(registrar: push.registrar,
                               preferences: push.notificationPreferences,
                               optIn: pushCoordinator,
                               pushSync: pushCoordinator,
                               logger: logger)
    }
}
