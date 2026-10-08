import SwiftUI

/// What a guest sees where a signed-in user's own content would be (Home, Chats): the shared empty state with a
/// Sign in button that presents the sheet. One view, so the two tabs cannot drift apart.
struct GuestSignInPrompt: View {
    let symbolName: String
    let message: String
    let dependencies: AppDependencies
    @State private var isSignInPresented = false

    var body: some View {
        EmptyStateView(symbolName: symbolName,
                       title: AppBranding.guestProfileTitle,
                       message: message,
                       actionTitle: AppBranding.signInAction) {
            isSignInPresented = true
        }
        .readableColumn()
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
        }
    }
}

#Preview {
    ContentScreen {
        GuestSignInPrompt(symbolName: DesignTokens.Symbols.home,
                          message: AppBranding.Home.guestMessage,
                          dependencies: .makeMock())
    }
}
