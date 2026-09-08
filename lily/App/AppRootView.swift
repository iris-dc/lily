import SwiftUI

/// Switches between launch, welcome and the main shell based on session state.
struct AppRootView: View {
    let dependencies: AppDependencies

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
        .animation(.smooth(duration: DesignTokens.Duration.slow), value: session.state.isInsideApp)
        .task { await session.restore() }
        .errorPopup(dependencies.errorCenter)
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
