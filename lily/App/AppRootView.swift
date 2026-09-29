import SwiftUI

/// Switches between launch, welcome and the main shell based on session state, and runs the per-user sync (account,
/// realtime connection, groups, inbox) whenever the scene phase or the user changes.
struct AppRootView: View {
    let dependencies: AppDependencies
    @Environment(\.scenePhase) private var scenePhase

    private var session: SessionController { dependencies.sessionController }

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
        .animation(.smooth(duration: DesignTokens.Duration.slow), value: rootScreen)
        .task {
            await session.restore()
            dependencies.navigation.selectedTab = AppNavigation.startTab(for: session.state)
        }
        // Going to the background is the last moment a small batch is sure to be sent.
        .onChange(of: scenePhase) {
            if scenePhase == .background { Task { await dependencies.interactionRecorder.flush() } }
        }
        .task(id: SyncKey(phase: scenePhase, userID: session.state.user?.id)) { await syncAccountAndRealtime() }
        .onChange(of: dependencies.myGroups.groups) { dependencies.myGroupsDidChange() }
        .onChange(of: dependencies.myGroups.loadVersion) { dependencies.myGroupsDidLoad() }
        .errorPopup(dependencies.errorCenter)
    }

    /// Which root is on screen; a change crossfades, so launch -> landing is as soft as landing -> shell.
    private var rootScreen: RootScreen {
        switch session.state {
        case .loading: .launch
        case .signedOut: .landing
        case .guest, .signedIn: .shell
        }
    }

    private enum RootScreen {
        case launch, landing, shell
    }

    /// What one run of the sync is for; a new key cancels the run still going for the old one.
    private struct SyncKey: Hashable {
        let phase: ScenePhase
        let userID: String?
    }

    /// The signed-in user's account, the realtime connection, their groups and their inbox, in that order: the account
    /// names the realtime endpoint, and a connection that opens reloads Mine itself (the resume protocol), so the
    /// store's own load afterwards is usually a no-op. The connection closes in the background; a guest has none of
    /// this and the stores clear themselves. A run stops at the first await after its key changed, so the phase it
    /// read is never applied over a newer one.
    private func syncAccountAndRealtime() async {
        let active = scenePhase != .background
        let user = session.state.user
        if active { await dependencies.me.loadIfNeeded() }
        guard !Task.isCancelled else { return }
        await dependencies.realtime.setDesired(active: active, user: user)
        guard !Task.isCancelled else { return }
        if active { await dependencies.myGroups.loadIfStale() }
        guard !Task.isCancelled else { return }
        if active { await dependencies.inbox.loadIfStale() }
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
