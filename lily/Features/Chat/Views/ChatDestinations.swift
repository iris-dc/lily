import SwiftUI

extension View {
    /// Pushes a room's `ChatView` on the stack the opener is on (a group's, a tournament's, an event's or a profile's
    /// detail), so Back returns to the opener; opening it on the Chats tab instead had Back land on the Chats root.
    func chatDestination(item: Binding<SportGroup?>, dependencies: AppDependencies) -> some View {
        modifier(InPlaceChatPush(item: item, dependencies: dependencies))
    }
}

/// An item push never moves the stack's bound path, so no prune ever frees the chat's tab-bar hide; the cleared item
/// binding is the pop signal instead — SwiftUI nils it on the pop alone, never on a tab switch, never under a cover,
/// both of which fire `onDisappear` while the chat keeps its place. The chat registers its hide under this
/// presenter's token (`\.tabBarHideToken`) and the clearing releases it.
private struct InPlaceChatPush: ViewModifier {
    @Binding var item: SportGroup?
    let dependencies: AppDependencies
    @Environment(\.tabBarHiding) private var hiding
    @State private var hideToken = UUID()

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $item) { room in
                ChatView(viewModel: dependencies.makeChatViewModel(for: room), dependencies: dependencies)
                    .environment(\.tabBarHideToken, AnyHashable(hideToken))
            }
            .onChange(of: item == nil) { _, cleared in
                if cleared { hiding?.release(hideToken) }
            }
    }
}
