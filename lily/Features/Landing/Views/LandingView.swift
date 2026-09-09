import SwiftUI

/// First screen. Explains the product in one glance and gets the user into the app in one tap.
struct LandingView: View {
    @State private var viewModel: LandingViewModel
    private let session: SessionController

    init(dependencies: AppDependencies) {
        session = dependencies.sessionController
        _viewModel = State(initialValue: LandingViewModel(session: dependencies.sessionController,
                                                          repository: dependencies.eventRepository,
                                                          logger: dependencies.logger))
    }

    var body: some View {
        ZStack {
            AuroraBackground(intensity: DesignTokens.Aurora.landingIntensity)
            VStack(alignment: .leading, spacing: 0) {
                Wordmark()
                    .padding(.top, DesignTokens.Spacing.md)
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
            SignInSheet(session: session)
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
                Button(AppBranding.signInAction) { viewModel.presentSignIn() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lilyInk)
                    .fontWeight(.semibold)
            }
            .font(LilyTheme.Fonts.caption)
            .frame(height: DesignTokens.Layout.controlHeight)
        }
    }
}

/// Multi-line headline; the last line carries the accent color.
struct LandingHeadline: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(AppBranding.headline.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(LilyTheme.Fonts.headline)
                    .tracking(DesignTokens.Typography.headlineTracking)
                    .foregroundStyle(index == AppBranding.headline.indices.last ? Color.lilyAccent : Color.lilyInk)
            }
            Text(AppBranding.subheadline)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, DesignTokens.Spacing.md)
        }
        .lineSpacing(DesignTokens.Typography.headlineLineSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Landing") {
    LandingView(dependencies: .makeMock())
}
