import Foundation

/// The event screens' view models over the shared repositories, changes tracker and the push opt-in.
extension AppDependencies {
    /// Explore starts from the filter as the user last left it (the defaults, 10 km around the user, on a fresh
    /// install) and keeps every change; a list without a filter button, such as Home, must never hide a game, so it
    /// starts from `.everything` and keeps nothing.
    func makeEventListViewModel(scope: EventScope) -> EventListViewModel {
        EventListViewModel(scope: scope,
                           repository: eventRepository,
                           identity: identity,
                           locationService: locationService,
                           changes: eventChanges,
                           errorCenter: errorCenter,
                           recorder: interactionRecorder,
                           logger: logger,
                           initialFilter: scope == .upcoming ? eventFilterStore.load() ?? EventFilter() : .everything,
                           filterStore: scope == .upcoming ? eventFilterStore : NoOpEventFilterStore())
    }

    /// Explore's filter as last set, forgotten by `-reset-session` like the session and the language choice, so UI
    /// tests and screenshot runs start from the defaults.
    static func makeEventFilterStore(arguments: [String], defaults: UserDefaults, logger: any Logging) -> any EventFilterStore {
        let store = UserDefaultsEventFilterStore(defaults: defaults, logger: logger)
        if arguments.contains(AppConfig.LaunchArguments.resetSession) { store.clear() }
        return store
    }

    func makeEventDetailViewModel(for event: SportEvent,
                                  onChange: @escaping @MainActor (SportEvent) -> Void) -> EventDetailViewModel {
        EventDetailViewModel(event: event,
                             repository: eventRepository,
                             identity: identity,
                             errorCenter: errorCenter,
                             recorder: interactionRecorder,
                             logger: logger,
                             pushOptIn: pushCoordinator,
                             onChange: onChange)
    }

    /// `onChange` receives the event as the backend stored it after the host's edit; the detail behind the sheet takes
    /// it through `EventDetailViewModel.accept`.
    func makeEditEventViewModel(for event: SportEvent,
                                onChange: @escaping @MainActor (SportEvent) -> Void) -> EditEventViewModel {
        EditEventViewModel(event: event,
                           repository: eventRepository,
                           errorCenter: errorCenter,
                           logger: logger,
                           onChange: onChange)
    }

    /// `onCreated` receives the event as the backend stored it; the list behind the sheet adds it in place. A sheet
    /// opened from a group's Events segment passes the group as `lockedGroup`, so the game is hosted there.
    func makeCreateEventViewModel(onCreated: @escaping @MainActor (SportEvent) -> Void,
                                  lockedGroup: EventGroupRef? = nil) -> CreateEventViewModel {
        CreateEventViewModel(repository: eventRepository,
                             identity: identity,
                             locationService: locationService,
                             groups: myGroups,
                             errorCenter: errorCenter,
                             logger: logger,
                             pushOptIn: pushCoordinator,
                             lockedGroup: lockedGroup,
                             onCreated: onCreated)
    }
}
