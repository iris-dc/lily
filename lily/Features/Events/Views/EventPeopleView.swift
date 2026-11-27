import SwiftUI

/// Opens the full "Who's in" list from the detail's People card. Carries the event itself, so any stack's registration
/// (`GroupDestinations`) builds the right list, however many details sit on it.
nonisolated struct EventPeopleDestination: Hashable {
    let event: SportEvent
}

/// Everyone in a game, split like the card that opens it: Hosting, then Going, each row opening the person's profile.
/// Fetches its own list on appear; the empty Going line shows only once a fetch answered.
struct EventPeopleView: View {
    let viewModel: EventPeopleViewModel

    private typealias Copy = AppBranding.People

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    if viewModel.isLoading, viewModel.participants.isEmpty {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        section(title: Copy.hostingRow, of: viewModel.hosting)
                        goingSection
                    }
                }
                .padding(DesignTokens.Layout.detailMargin)
                .readableColumn()
            }
        }
        .navigationTitle(AppBranding.Events.participantsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .hidesTabBarOnCompact()
        .task { await viewModel.load() }
    }

    @ViewBuilder private var goingSection: some View {
        if viewModel.going.isEmpty {
            if viewModel.hasLoaded {
                DetailSection(title: Copy.goingRow) {
                    Text(Copy.nobodyGoingYet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            section(title: Copy.goingRow, of: viewModel.going)
        }
    }

    private func section(title: String, of people: [EventParticipant]) -> some View {
        DetailSection(title: title) {
            ForEach(people) { participant in
                ParticipantRow(participant: participant, isSelf: viewModel.isSelf(participant))
            }
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        EventPeopleView(viewModel: dependencies.makeEventPeopleViewModel(for: MockEventFixtures.make(now: .now, count: 1)[0]))
    }
}
