import SwiftUI

/// Event detail with the join/leave control. The view model decides what the control is; this only draws it.
struct EventDetailView: View {
    @State private var viewModel: EventDetailViewModel

    init(viewModel: EventDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var event: SportEvent { viewModel.event }

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    SportChip(sport: event.sport)
                    ScreenTitle(text: event.title, subtitle: AppBranding.hostedByTitle(for: event.hostName))
                    GlassCard { details }
                    participationControl
                }
                .padding(DesignTokens.Spacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Label(event.startsAt.formatted(date: .abbreviated, time: .shortened), systemImage: DesignTokens.Symbols.time)
            Label(event.locationName, systemImage: DesignTokens.Symbols.location)
            CapacityBar(event: event)
        }
    }

    @ViewBuilder
    private var participationControl: some View {
        switch viewModel.participation {
        case .hidden:
            EmptyView()
        case .join:
            actionButton(AppBranding.joinAction) { await viewModel.join() }
                .lilyProminentButton()
        case .leave:
            actionButton(AppBranding.leaveAction) { await viewModel.leave() }
                .lilyGlassButton()
        case .full:
            actionButton(AppBranding.eventFullAction)
                .lilyProminentButton()
        case .hosting:
            Text(AppBranding.hostingNotice)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Full-width action with a spinner beside its title while the request runs. Without an action it is disabled.
    private func actionButton(_ title: String, action: (() async -> Void)? = nil) -> some View {
        Button {
            Task { await action?() }
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Text(title)
                if viewModel.isBusy {
                    ProgressView().controlSize(.small)
                }
            }
            .fullWidthButtonLabel()
        }
        .disabled(action == nil || viewModel.isBusy)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for: MockEventFixtures.make(now: .now, count: 1)[0],
                                                                         onChange: { _ in }))
    }
}
