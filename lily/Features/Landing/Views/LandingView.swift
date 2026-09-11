import SwiftUI

/// First screen. Explains the product in one glance and gets the user into the app in one tap.
struct LandingView: View {
    @State private var viewModel: LandingViewModel
    private let session: SessionController
    private let errorCenter: ErrorCenter

    init(dependencies: AppDependencies) {
        session = dependencies.sessionController
        errorCenter = dependencies.errorCenter
        _viewModel = State(initialValue: LandingViewModel(session: dependencies.sessionController,
                                                          repository: dependencies.eventRepository,
                                                          logger: dependencies.logger))
    }

    var body: some View {
        ZStack {
            AuroraBackground(intensity: DesignTokens.Aurora.landingIntensity)
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: DesignTokens.Spacing.xl)
                LandingHeadline()
                Spacer(minLength: DesignTokens.Spacing.xl)
                EventPreviewDeck(events: viewModel.previewEvents)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: DesignTokens.Spacing.xl)
                actions
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.bottom, DesignTokens.Spacing.lg)
        }
        .task { await viewModel.loadPreview() }
        .sheet(isPresented: $viewModel.isSignInPresented) {
            SignInSheet(session: session, errorCenter: errorCenter)
        }
    }

    private var actions: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Button { viewModel.enterApp() } label: {
                Text(AppBranding.landingPrimaryAction).fullWidthButtonLabel()
            }
            .lilyProminentButton()
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(AppBranding.signInPrompt)
                    .foregroundStyle(.secondary)
                Button { viewModel.presentSignIn() } label: {
                    Text(AppBranding.signInAction).tappableTextLabel()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.lilyInk)
                .fontWeight(.semibold)
            }
            .font(LilyTheme.Fonts.caption)
        }
    }
}

/// Multi-line headline; the last line carries the accent color.
struct LandingHeadline: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Each line is its own Text, so the tight line gap is the stack spacing, not `lineSpacing`.
            VStack(alignment: .leading, spacing: DesignTokens.Typography.headlineLineSpacing) {
                ForEach(Array(AppBranding.headline.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(LilyTheme.Fonts.headline)
                        .tracking(DesignTokens.Typography.headlineTracking)
                        .foregroundStyle(index == AppBranding.headline.indices.last ? Color.lilyAccent : Color.lilyInk)
                }
            }
            Text(AppBranding.subheadline)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, DesignTokens.Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Landing") {
    LandingView(dependencies: .makeMock())
}
