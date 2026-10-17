import SwiftUI

/// First screen: a swipeable intro of full-page slides (the events to find, how to join one, the groups, the
/// tournaments), each a framed miniature of a real screen over the aurora, with the two ways into the app pinned under
/// every slide.
struct LandingView: View {
    @State private var viewModel: LandingViewModel
    @State private var visibleSlide: IntroSlide? = .first
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(initialValue: dependencies.makeLandingViewModel())
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
                    // Wider than any phone's content, so compact is unchanged; on an iPad the capsules stop stretching.
                    .readableColumn(maxWidth: DesignTokens.Layout.landingButtonMaxWidth)
                    .padding(.top, DesignTokens.Spacing.md)
                    .padding(.horizontal, DesignTokens.Spacing.xl)
                    .padding(.bottom, DesignTokens.Spacing.lg)
            }
        }
        .onChange(of: visibleSlide) { viewModel.slideShown(visibleSlide) }
        .task { await viewModel.loadPreview() }
        .sheet(isPresented: $viewModel.isSignInPresented) {
            SignInSheet(session: dependencies.sessionController, errorCenter: dependencies.errorCenter)
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

/// A slide's caption: two headline lines, the last in the accent colour.
struct LandingHeadline: View {
    let lines: [String]

    var body: some View {
        // Each line is its own Text, so the tight line gap is the stack spacing, not `lineSpacing`.
        VStack(alignment: .leading, spacing: DesignTokens.Typography.headlineLineSpacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HeadlineLine(text: line, color: index == lines.indices.last ? Color.lilyAccent : Color.lilyInk)
            }
        }
        // The lines take the height they need: on a short page (the SE) the slide's stack proposes the caption about
        // one line, and a wrapped line would truncate to "De vrais matchs…" instead; the miniature gives way.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// One headline line, never truncated: on one line at full size when it fits, shrunk to `headlineMinimumScale` when
/// that is enough (a line that just overflows the SE's 375 pt), wrapped otherwise (a translation half again as wide
/// as the English; a bare `lineLimit(1)` cut such lines to "…" on every phone).
private struct HeadlineLine: View {
    let text: String
    let color: Color

    var body: some View {
        ViewThatFits(in: .horizontal) {
            line(scale: 1).lineLimit(1)
            line(scale: DesignTokens.Layout.headlineMinimumScale).lineLimit(1)
            line(scale: 1)
        }
    }

    private func line(scale: CGFloat) -> some View {
        Text(text)
            .font(LilyTheme.Fonts.headline(scale: scale))
            .tracking(DesignTokens.Typography.headlineTracking * scale)
            .foregroundStyle(color)
    }
}

#Preview("Landing") {
    LandingView(dependencies: .makeMock())
}
