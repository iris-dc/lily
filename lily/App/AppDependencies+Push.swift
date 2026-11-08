import Foundation

/// The push collaborators, built as one value so `AppDependencies` gains a single stored property: the coordinator
/// over the registrar and device repository the data layer chose (system or mock) and the game opener it shares with
/// the inbox; the tournament opener behind a match reminder's tap is the coordinator's alone.
struct PushDependencies {
    let registrar: any PushRegistrar
    let devices: any DeviceRepository
    let opener: EventOpener
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
        coordinator = PushCoordinator(registrar: registrar,
                                      devices: devices,
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
}
