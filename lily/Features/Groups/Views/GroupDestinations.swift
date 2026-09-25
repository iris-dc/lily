import SwiftUI

/// The group destinations every `NavigationStack` root registers, so a "Hosted in" link works from Explore and My
/// Events as well as from the Groups tab: a group, a group reached from its chat, a group reference that still has to
/// be fetched, and a chat.
private struct GroupDestinations: ViewModifier {
    let dependencies: AppDependencies
    /// Receives a group as the detail changed it; the list behind the detail replaces its row.
    let onGroupChange: @MainActor (SportGroup) -> Void

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
    }

    private func detail(for group: SportGroup, context: GroupDetailContext) -> some View {
        GroupDetailView(viewModel: dependencies.makeGroupDetailViewModel(for: group, context: context, onChange: onGroupChange),
                        dependencies: dependencies)
    }
}

extension View {
    func groupDestinations(dependencies: AppDependencies,
                           onGroupChange: @escaping @MainActor (SportGroup) -> Void = { _ in }) -> some View {
        modifier(GroupDestinations(dependencies: dependencies, onGroupChange: onGroupChange))
    }
}
