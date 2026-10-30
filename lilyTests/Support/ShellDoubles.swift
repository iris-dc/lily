import Foundation
@testable import lily

extension ShellSync {
    /// The sync over the harnesses' stores and coordinators, with the tabs' lists over the realtime harness' fakes
    /// (`events`, `tournaments`, `groups`), so a run's Explore loads are observable there.
    @MainActor
    static func make(session: SessionController,
                     navigation: AppNavigation,
                     realtime: RealtimeHarness,
                     push: PushHarness) -> ShellSync {
        ShellSync(session: session,
                  navigation: navigation,
                  me: realtime.me,
                  realtime: realtime.controller,
                  myGroups: realtime.store,
                  inbox: realtime.inbox,
                  blocks: realtime.blocks,
                  push: push.coordinator,
                  lists: ShellLists.make(realtime: realtime))
    }
}

extension ShellLists {
    /// Home's and Explore's lists over the realtime harness' fakes.
    @MainActor
    static func make(realtime: RealtimeHarness) -> ShellLists {
        ShellLists(homeEvents: makeEvents(scope: .joined, realtime: realtime),
                   homeTournaments: makeTournaments(scope: .mine, realtime: realtime),
                   exploreEvents: makeEvents(scope: .upcoming, realtime: realtime),
                   discover: DiscoverGroupsViewModel(changes: realtime.changes,
                                                     repository: realtime.groups,
                                                     identity: realtime.identity,
                                                     locationService: MockLocationService(),
                                                     errorCenter: realtime.errorCenter,
                                                     recorder: realtime.recorder,
                                                     logger: realtime.logger),
                   exploreTournaments: makeTournaments(scope: .upcoming, realtime: realtime))
    }

    @MainActor
    private static func makeEvents(scope: EventScope, realtime: RealtimeHarness) -> EventListViewModel {
        makeEventListViewModel(scope: scope, repository: realtime.events, identity: realtime.identity)
    }

    @MainActor
    private static func makeTournaments(scope: TournamentScope, realtime: RealtimeHarness) -> TournamentListViewModel {
        TournamentListViewModel(scope: scope,
                                repository: realtime.tournaments,
                                identity: realtime.identity,
                                locationService: MockLocationService(),
                                changes: realtime.tournamentChanges,
                                errorCenter: realtime.errorCenter,
                                logger: realtime.logger)
    }
}
