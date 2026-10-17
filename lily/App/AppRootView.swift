import SwiftUI

/// Switches between the landing and the main shell on the session state (which starts from the cache, so the first
/// frame is already one of the two), ties `ShellSync` to the scene phase and the user (the restore once, a run
/// whenever either changes), and presents the terms sheet while a signed-in caller owes the current terms. Wiring only:
/// what a run does, and in which order, is `ShellSync`'s.
struct AppRootView: View {
    let dependencies: AppDependencies
    @State private var terms: TermsViewModel
    @State private var sync: ShellSync
    @Environment(\.scenePhase) private var scenePhase

    private var session: SessionController { dependencies.sessionController }
    private var language: LanguageStore { dependencies.language }

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _terms = State(initialValue: dependencies.makeTermsViewModel())
        _sync = State(initialValue: dependencies.makeShellSync())
    }

    var body: some View {
        Group {
            switch session.state {
            case .signedOut:
                LandingView(dependencies: dependencies)
            case .guest, .signedIn:
                MainTabView(dependencies: dependencies)
            }
        }
        // Copy is read into views as plain strings, so a new language needs the tree rebuilt, not re-rendered.
        .id(language.language)
        .environment(\.locale, language.locale)
        .environment(\.auroraFrozen, dependencies.freezesAurora)
        .layoutModeProvider()
        .animation(.smooth(duration: DesignTokens.Duration.slow), value: rootScreen)
        .task { await sync.restore() }
        // Going to the background is the last moment a small batch is sure to be sent.
        .onChange(of: scenePhase) {
            if scenePhase == .background { Task { await dependencies.interactionRecorder.flush() } }
        }
        .task(id: SyncKey(phase: scenePhase, userID: session.state.user?.id, language: language.language)) {
            await sync.run(active: scenePhase != .background, user: session.state.user)
        }
        .onChange(of: dependencies.myGroups.groups) { dependencies.myGroupsDidChange() }
        .onChange(of: dependencies.myGroups.loadVersion) { dependencies.myGroupsDidLoad() }
        .errorPopup(dependencies.errorCenter)
        .sheet(isPresented: termsPresented) {
            TermsSheet(viewModel: terms, errorCenter: dependencies.errorCenter)
        }
    }

    /// The setter is empty on purpose: the sheet cannot be swiped away. It follows `MeStore.needsTerms` and goes only
    /// once the acceptance is recorded or the session ends.
    private var termsPresented: Binding<Bool> {
        Binding(get: { terms.isPresented }, set: { _ in })
    }

    /// Which root is on screen; a change crossfades between the two.
    private var rootScreen: RootScreen {
        switch session.state {
        case .signedOut: .landing
        case .guest, .signedIn: .shell
        }
    }

    private enum RootScreen {
        case landing, shell
    }

    /// What one run of the sync is for; a new key cancels the run still going for the old one. The language is part of
    /// it so a change registers the device again, in the new language.
    private struct SyncKey: Hashable {
        let phase: ScenePhase
        let userID: String?
        let language: AppLanguage
    }
}

#Preview {
    AppRootView(dependencies: .makeMock())
}
