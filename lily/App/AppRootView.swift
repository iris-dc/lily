import SwiftUI

/// Switches between launch, welcome and the main shell based on session state. Also the one place an invite link
/// surfaces: the preview is a sheet over the root, so it draws above every tab.
struct AppRootView: View {
    let dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase

    private var session: SessionController { dependencies.sessionController }
    private var deepLinks: DeepLinkCenter { dependencies.deepLinks }

    var body: some View {
        Group {
            switch session.state {
            case .loading:
                LaunchView()
            case .signedOut:
                LandingView(dependencies: dependencies)
            case .guest, .signedIn:
                MainTabView(dependencies: dependencies)
            }
        }
        .animation(.smooth(duration: DesignTokens.Duration.slow), value: session.state.isInsideApp)
        .task { await session.restore() }
        // Going to the background is the last moment a small batch is sure to be sent.
        .onChange(of: scenePhase) {
            if scenePhase == .background { Task { await dependencies.interactionRecorder.flush() } }
            Task { await syncAccountAndRealtime() }
        }
        .onChange(of: session.state.user) { Task { await syncAccountAndRealtime() } }
        .onChange(of: dependencies.myGroups.groups) { dependencies.myGroupsDidChange() }
        .onOpenURL { deepLinks.handle($0) }
        .onChange(of: deepLinks.pendingInvite, initial: true) { enterAppForPendingInvite() }
        .onChange(of: session.state) { enterAppForPendingInvite() }
        .sheet(item: presentedInvite) { code in
            InvitePreviewSheet(viewModel: dependencies.makeInvitePreviewViewModel(code: code) { _ in },
                               dependencies: dependencies)
        }
        .errorPopup(dependencies.errorCenter)
    }

    /// The invite waits while the session is still being restored; the sheet shows once the shell is up.
    private var presentedInvite: Binding<InviteCode?> {
        Binding(get: { session.state.isInsideApp ? deepLinks.pendingInvite : nil },
                set: { deepLinks.pendingInvite = $0 })
    }

    /// An invite opened from the landing enters the app as a guest first, so the preview appears over the app.
    private func enterAppForPendingInvite() {
        if deepLinks.pendingInvite != nil, session.state == .signedOut {
            session.continueAsGuest()
        }
    }

    /// The signed-in user's account, the realtime connection and their groups, in that order: the account names the
    /// realtime endpoint, and a connection that opens reloads Mine itself (the resume protocol), so the store's own
    /// load afterwards is usually a no-op. The connection closes in the background; a guest has none of this and the
    /// stores clear themselves.
    private func syncAccountAndRealtime() async {
        let active = scenePhase != .background
        if active { await dependencies.me.loadIfNeeded() }
        await dependencies.realtime.setDesired(active: active, user: session.state.user)
        if active { await dependencies.myGroups.loadIfStale() }
    }
}

/// Shown only while the session is being restored.
private struct LaunchView: View {
    var body: some View {
        ZStack {
            AuroraBackground()
            Wordmark(size: DesignTokens.Typography.headlineSize)
        }
    }
}

#Preview {
    AppRootView(dependencies: .makeMock())
}
