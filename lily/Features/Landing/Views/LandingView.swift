import SwiftUI

/// First screen: a swipeable intro of three full-page slides (what this is, how to join, what else it offers), each a
/// framed miniature of a real screen over the aurora, with the two ways into the app pinned under every slide.
struct LandingView: View {
    @State private var viewModel: LandingViewModel
    @State private var visibleSlide: IntroSlide? = .first
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
            VStack(spacing: 0) {
                IntroPager(slides: viewModel.slides,
                           content: viewModel.introContent,
                           showsSwipeHint: viewModel.showsSwipeHint,
                           visibleSlide: $visibleSlide)
                    .overlay(alignment: .trailing) {
                        // At the edge, vertically centred: a row of bars under the slides read as "swipe sideways".
                        IntroPageIndicator(slides: viewModel.slides, current: viewModel.currentSlide)
                            .padding(.trailing, DesignTokens.Spacing.lg)
                    }
                actions
                    .padding(.top, DesignTokens.Spacing.md)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .padding(.bottom, DesignTokens.Spacing.lg)
            }
        }
        .onChange(of: visibleSlide) { viewModel.slideShown(visibleSlide) }
        .task { await viewModel.loadPreview() }
        .sheet(isPresented: $viewModel.isSignInPresented) {
            SignInSheet(session: session, errorCenter: errorCenter)
        }
    }

    /// Two stacked full-width capsules: the prominent way in, and sign-in as a quieter glass button under it.
    private var actions: some View {
        GlassEffectContainer(spacing: DesignTokens.Spacing.md) {
            VStack(spacing: DesignTokens.Spacing.md) {
                Button(AppBranding.landingPrimaryAction) { viewModel.enterApp() }
                    .lilyProminentButton()
                Button(AppBranding.signInAction) { viewModel.presentSignIn() }
                    .lilyGlassButton(labelColor: .lilyInk)
            }
        }
    }
}

/// A slide's caption: two headline lines, the last in the accent colour, and the message under them.
struct LandingHeadline: View {
    let lines: [String]
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Each line is its own Text, so the tight line gap is the stack spacing, not `lineSpacing`.
            VStack(alignment: .leading, spacing: DesignTokens.Typography.headlineLineSpacing) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(LilyTheme.Fonts.headline)
                        .tracking(DesignTokens.Typography.headlineTracking)
                        .foregroundStyle(index == lines.indices.last ? Color.lilyAccent : Color.lilyInk)
                }
            }
            Text(subtitle)
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
