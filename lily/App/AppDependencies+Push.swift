import Foundation

/// The push collaborators, built as one value so `AppDependencies` gains a single stored property: the coordinator
/// over the registrar and device repository the data layer chose (system or mock), and the opener it shares with the
/// inbox.
struct PushDependencies {
    let registrar: any PushRegistrar
    let devices: any DeviceRepository
    let opener: EventOpener
    let coordinator: PushCoordinator

    init(registrar: any PushRegistrar,
         devices: any DeviceRepository,
         events: any EventRepository,
         identity: any IdentityProvider,
         groups: GroupDependencies,
         defaults: UserDefaults,
         logger: any Logging) {
        let opener = EventOpener(events: events,
                                 navigation: groups.navigation,
                                 reporter: groups.errorReporter,
                                 logger: logger)
        self.opener = opener
        self.registrar = registrar
        self.devices = devices
        coordinator = PushCoordinator(registrar: registrar,
                                      devices: devices,
                                      identity: identity,
                                      opener: opener,
                                      defaults: defaults,
                                      logger: logger)
    }
}

extension AppDependencies {
    var pushCoordinator: PushCoordinator { push.coordinator }
    var eventOpener: EventOpener { push.opener }
}
