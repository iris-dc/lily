import SwiftUI

/// The Chats tab. Its root is the one `NavigationStack` bound to `AppNavigation.chatPath`, so a room opened from
/// elsewhere in the app (a group's "Open chat", an accepted invite) lands here.
struct ChatTab: View {
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        NavigationStack(path: $navigation.chatPath) {
            ChatsView(dependencies: dependencies)
        }
    }
}

#Preview {
    ChatTab(dependencies: .makeMock())
}
