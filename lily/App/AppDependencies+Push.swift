import Foundation

/// The push collaborators, built as one value so `AppDependencies` gains a single stored property: the coordinator
/// over the registrar and device repository the data layer chose (system or mock), the game opener it shares with the
/// inbox, and the tournament opener behind a match reminder's tap.
struct PushDependencies {
    let registrar: any PushRegistrar
    let devices: any DeviceRepository
    let opener: EventOpener
    let tournamentOpener: TournamentOpener
    let coordinator: PushCoordinator

    init(registrar: any PushRegistrar,
         devices: any DeviceRepository,
         events: any EventRepository,
         tournaments: any TournamentRepository,
         identity: any IdentityProvider,
         groups: GroupDependencies,
         defaults: UserDefaults,
         languageCode: @escaping () -> String,
         logger: any Logging) {
        let opener = EventOpener(events: events,
                                 navigation: groups.navigation,
                                 reporter: groups.errorReporter,
                                 logger: logger)
        let tournamentOpener = TournamentOpener(tournaments: tournaments,
                                                navigation: groups.navigation,
                                                reporter: groups.errorReporter,
                                                logger: logger)
        self.opener = opener
        self.tournamentOpener = tournamentOpener
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
    var tournamentOpener: TournamentOpener { push.tournamentOpener }
}
