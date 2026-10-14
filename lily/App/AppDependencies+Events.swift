import Foundation

/// The event screens' and the landing's view models over the shared repositories, changes tracker and the push opt-in.
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
                           currencyCode: { [currency] in currency.currencyCode },
                           initialFilter: scope == .upcoming ? eventFilterStore.load() ?? EventFilter() : .everything,
                           filterStore: scope == .upcoming ? eventFilterStore : NoOpEventFilterStore())
    }

    /// Explore's filter as last set, forgotten on a fresh start (`-reset-session`, decided and logged once by
    /// `makeDefault`) like the session and the language choice, so UI tests and screenshot runs start from the defaults.
    static func makeEventFilterStore(startsFresh: Bool, defaults: UserDefaults, logger: any Logging) -> any EventFilterStore {
        let store = UserDefaultsEventFilterStore(defaults: defaults, logger: logger)
        if startsFresh { store.clear() }
        return store
    }

    /// The landing's intro and its two ways in (enter as a guest, sign in) over the event preview; `now` keeps its
    /// default, so the intro's sample cards are dated from launch.
    func makeLandingViewModel() -> LandingViewModel {
        LandingViewModel(session: sessionController, repository: eventRepository, logger: logger)
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
                           currencyCode: currency.currencyCode,
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
                             currencyCode: currency.currencyCode,
                             pushOptIn: pushCoordinator,
                             lockedGroup: lockedGroup,
                             onCreated: onCreated)
    }
}
