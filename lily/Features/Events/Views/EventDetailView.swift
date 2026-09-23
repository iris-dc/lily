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
                    EventTypeChip(type: event.type)
                    ScreenTitle(text: event.title, subtitle: AppBranding.hostedByTitle(for: event.hostName))
                    if let description = event.description {
                        Text(description).font(.body)
                    }
                    facts
                    if let lookingFor = event.lookingFor {
                        lookingForCard(lookingFor)
                    }
                    participationControl
                }
                .padding(DesignTokens.Spacing.xl)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.recordViewed() }
    }

    /// Time, place, price and level, then how full it is. Price only when the game costs something, level only when set.
    private var facts: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Label(event.startsAt.formatted(date: .abbreviated, time: .shortened), systemImage: DesignTokens.Symbols.time)
                Label(event.locationName, systemImage: DesignTokens.Symbols.location)
                if !event.isFree {
                    Label(AppBranding.Events.perPerson(event.priceText), systemImage: DesignTokens.Symbols.price)
                }
                if let level = event.skillLevel {
                    Label(AppBranding.Events.level(level.displayName), systemImage: DesignTokens.Symbols.level)
                }
                CapacityBar(event: event)
            }
            .labelStyle(.iconColumn)
        }
    }

    private func lookingForCard(_ text: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Label(AppBranding.Events.lookingForTitle, systemImage: DesignTokens.Symbols.lookingFor)
                    .labelStyle(.iconColumn)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                Text(text).font(.body)
            }
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

    /// Action with a spinner beside its title while the request runs. Without an action it is disabled. The caller
    /// applies the button style, which also sets the full width and height (see the Buttons note in CLAUDE.md).
    private func actionButton(_ title: String, action: (() async -> Void)? = nil) -> some View {
        Button {
            Task { await action?() }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                if viewModel.isBusy {
                    // The button's `.large` control size would inflate the spinner past the text height.
                    ProgressView()
                        .controlSize(.regular)
                        .accessibilityHidden(true)
                }
            }
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
