import SwiftUI

extension View {
    /// Pushes a room's `ChatView` on the stack the opener is on (a group's, a tournament's or a profile's detail),
    /// so Back returns to the opener; opening it on the Chats tab instead had Back land on the Chats root. The chat
    /// gets `\.tabBarHiding` nil: an item push never moves the stack's bound path, so a path-keyed registry would
    /// never prune the chat's tab-bar hide after the pop; without it the chat sets the bar's visibility itself and
    /// the bar returns with the screen.
    func chatDestination(item: Binding<SportGroup?>, dependencies: AppDependencies) -> some View {
        navigationDestination(item: item) { room in
            ChatView(viewModel: dependencies.makeChatViewModel(for: room), dependencies: dependencies)
                .environment(\.tabBarHiding, nil)
        }
    }
}
