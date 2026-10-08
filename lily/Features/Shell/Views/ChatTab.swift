import SwiftUI

/// The Chats tab. On a compact width its root is the one `NavigationStack` bound to `AppNavigation.chatPath`, so a
/// room opened from elsewhere in the app (a group's "Open chat", an accepted invite) lands here; on a regular width
/// a signed-in caller gets the split view, whose detail column holds that stack instead. A guest sees the sign-in
/// prompt at full width either way: a prompt beside an empty detail would say the same thing twice.
struct ChatTab: View {
    let dependencies: AppDependencies
    @Environment(\.layoutMode) private var layoutMode

    private var showsSplitView: Bool {
        layoutMode.isRegular && HomeContent(for: dependencies.sessionController.state) == .overview
    }

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        if showsSplitView {
            ChatsSplitView(dependencies: dependencies)
        } else {
            NavigationStack(path: $navigation.chatPath) {
                ChatsView(dependencies: dependencies)
            }
        }
    }
}

#Preview {
    ChatTab(dependencies: .makeMock())
}
