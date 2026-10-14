import SwiftUI

/// The group destinations every `NavigationStack` root registers, so a "Hosted in" link works from Explore as well as
/// from Home: a group, a group reached from its chat, a group reference that still has to be fetched, a chat, the
/// Discover screens, a person's profile and a tournament. A direct conversation pushed as a group shows the other
/// person's profile and a tournament's room its tournament: neither has a group detail of its own.
private struct GroupDestinations: ViewModifier {
    let dependencies: AppDependencies
    /// What a tournament detail pushed on this stack hands back after a write.
    let onTournamentChange: @MainActor (Tournament) -> Void

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: SportGroup.self) { detail(for: $0, context: .standalone) }
            .navigationDestination(for: GroupInfoDestination.self) { detail(for: $0.group, context: .fromChat) }
            .navigationDestination(for: EventGroupRef.self) { ref in
                GroupLoaderView(viewModel: dependencies.makeGroupLoaderViewModel(ref: ref), dependencies: dependencies)
            }
            .navigationDestination(for: ChatDestination.self) { destination in
                ChatView(viewModel: dependencies.makeChatViewModel(for: destination.group), dependencies: dependencies)
            }
            .navigationDestination(for: DiscoverGroupsDestination.self) { _ in
                DiscoverGroupsView(dependencies: dependencies)
            }
            .navigationDestination(for: UserProfileDestination.self) { destination in
                UserProfileView(viewModel: dependencies.makeUserProfileViewModel(for: destination))
            }
            .navigationDestination(for: TournamentDestination.self) { destination in
                tournamentDetail(for: destination)
            }
            .navigationDestination(for: DiscoverTournamentsDestination.self) { _ in
                DiscoverTournamentsView(dependencies: dependencies)
            }
    }

    /// The detail's answer goes to the root's `onTournamentChange`: Home's Mine list replaces its row with it, every
    /// other root records the change for the lists to reload on.
    private func tournamentDetail(for destination: TournamentDestination) -> some View {
        TournamentDetailView(viewModel: dependencies.makeTournamentDetailViewModel(for: destination,
                                                                                   onChange: onTournamentChange),
                             dependencies: dependencies)
    }

    @ViewBuilder private func detail(for group: SportGroup, context: GroupDetailContext) -> some View {
        if let counterpart = group.counterpart {
            UserProfileView(viewModel: dependencies.makeUserProfileViewModel(for: counterpart.profile()))
        } else if group.isTournamentRoom {
            tournamentDetail(for: TournamentDestination(id: group.id, name: group.name))
        } else {
            // Home draws Mine from the store and Discover searches again on `groupChanges`, so the detail hands
            // nothing back.
            GroupDetailView(viewModel: dependencies.makeGroupDetailViewModel(for: group, context: context),
                            dependencies: dependencies)
        }
    }
}

extension View {
    /// `onTournamentChange` is what a tournament detail pushed on this stack hands back after a write. Home passes its
    /// Mine list's `replace`, so the row changes in place, drops when the caller left, or appears when they entered from
    /// a group's segment pushed on this stack; every other root takes the default, which records the change every list
    /// reloads on.
    func groupDestinations(dependencies: AppDependencies,
                           onTournamentChange: (@MainActor (Tournament) -> Void)? = nil) -> some View {
        let onChange = onTournamentChange ?? { _ in dependencies.tournamentChanges.recordChange() }
        return modifier(GroupDestinations(dependencies: dependencies, onTournamentChange: onChange))
    }
}
