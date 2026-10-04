import SwiftUI

/// The group destinations every `NavigationStack` root registers, so a "Hosted in" link works from Explore as well as
/// from Home: a group, a group reached from its chat, a group reference that still has to be fetched, a chat, the
/// Discover screens, a person's profile and a tournament. A direct conversation pushed as a group shows the other
/// person's profile and a tournament's room its tournament: neither has a group detail of its own.
private struct GroupDestinations: ViewModifier {
    let dependencies: AppDependencies

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

    /// Every list reloads on `tournamentChanges`, so a change made on the detail only has to be recorded.
    private func tournamentDetail(for destination: TournamentDestination) -> some View {
        TournamentDetailView(viewModel: dependencies.makeTournamentDetailViewModel(for: destination) { _ in
            dependencies.tournamentChanges.recordChange()
        }, dependencies: dependencies)
    }

    @ViewBuilder private func detail(for group: SportGroup, context: GroupDetailContext) -> some View {
        if let counterpart = group.counterpart {
            UserProfileView(viewModel: dependencies.makeUserProfileViewModel(for: counterpart.profile()))
        } else if group.isTournamentRoom {
            tournamentDetail(for: TournamentDestination(id: group.id, name: group.name))
        } else {
            // Home shows the caller's groups from the store and Discover searches again after a change, so nothing
            // listens here.
            GroupDetailView(viewModel: dependencies.makeGroupDetailViewModel(for: group, context: context) { _ in },
                            dependencies: dependencies)
        }
    }
}

extension View {
    func groupDestinations(dependencies: AppDependencies) -> some View {
        modifier(GroupDestinations(dependencies: dependencies))
    }
}
