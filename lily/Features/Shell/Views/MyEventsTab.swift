import SwiftUI

/// The My Events tab. Joined events are scoped to a user, so a guest gets a sign-in prompt instead of a `.joined`
/// request that nothing could answer.
struct MyEventsTab: View {
    let dependencies: AppDependencies

    var body: some View {
        switch MyEventsContent(for: dependencies.sessionController.state) {
        case .signInPrompt:
            GuestMyEventsView(dependencies: dependencies)
        case .joinedEvents:
            EventListView(
                title: AppBranding.myEventsTitle,
                emptyState: EmptyStateView(symbolName: DesignTokens.Symbols.addEvent,
                                           title: AppBranding.myEventsEmptyTitle,
                                           message: AppBranding.myEventsEmptyMessage),
                scope: .joined,
                dependencies: dependencies
            )
        }
    }
}

/// Empty state with a sign-in button; the sheet is presented from here so the tab keeps its own navigation bar.
private struct GuestMyEventsView: View {
    let dependencies: AppDependencies
    @State private var isSignInPresented = false

    var body: some View {
        NavigationStack {
            ContentScreen {
                EmptyStateView(symbolName: DesignTokens.Symbols.myEvents,
                               title: AppBranding.guestProfileTitle,
                               message: AppBranding.guestProfileMessage,
                               actionTitle: AppBranding.signInAction) {
                    isSignInPresented = true
                }
            }
            .navigationTitle(AppBranding.myEventsTitle)
            .groupDestinations(dependencies: dependencies)
        }
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
        }
    }
}

#Preview {
    MyEventsTab(dependencies: .makeMock())
}
