import SwiftUI

/// The group destinations every `NavigationStack` root registers, so a "Hosted in" link works from Explore as well as
/// from Home: a group, a group reached from its chat, a group reference that still has to be fetched, a chat, and the
/// Discover screen.
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
    }

    private func detail(for group: SportGroup, context: GroupDetailContext) -> some View {
        // Home shows the caller's groups from the store and Discover searches again after a change, so nothing
        // listens here.
        GroupDetailView(viewModel: dependencies.makeGroupDetailViewModel(for: group, context: context) { _ in },
                        dependencies: dependencies)
    }
}

extension View {
    func groupDestinations(dependencies: AppDependencies) -> some View {
        modifier(GroupDestinations(dependencies: dependencies))
    }
}
