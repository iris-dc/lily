import SwiftUI

/// The redesigned detail's blocks: the centered header with the outcome, the facts and People cards, the segments and
/// the pinned action bar. In an extension so the view's main file keeps the wiring alone.
extension TournamentDetailView {
    private typealias People = AppBranding.People

    /// Everything sits in the readable column except a bracket, which keeps the whole width and scrolls under both
    /// screen edges, its first column lined up with the text above it. A preview (the opener's copy, the fetch still
    /// out) draws the header, the facts and the People card, and a spinner where the bracket and matches will be.
    func content(_ detail: TournamentDetail, isPreview: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    header(detail.tournament)
                    DetailSection(title: People.detailsSection) {
                        TournamentFacts(tournament: detail.tournament)
                    }
                    peopleSection(detail, isPreview: isPreview)
                    aboutSection(detail.tournament)
                    if viewModel.permissions.showsEntries {
                        sectionPicker(detail.tournament)
                    }
                }
                .inReadableColumn()
                if viewModel.permissions.showsEntries {
                    if isPreview {
                        loadingSlot
                    } else {
                        segment(detail)
                    }
                }
            }
            .padding(.vertical, DesignTokens.Layout.detailMargin)
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) { contentWidth = $0 }
        .refreshable { await viewModel.load() }
    }

    /// The sport, the name, and the format with the status in one line; the winner or the cancelled notice under it
    /// once there is one.
    private func header(_ tournament: Tournament) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            DetailHeader(symbolName: tournament.type.symbolName,
                         title: tournament.name,
                         caption: AppBranding.Groups.caption([tournament.format.displayName,
                                                              tournament.status.displayName]))
            TournamentOutcomeLine(tournament: tournament, winnerName: viewModel.winnerName)
        }
    }

    /// Who organises the tournament and who entered: the first entries' circles and the count; the entries row opens
    /// the full list once the detail answered, the organiser their profile when the caller may see it.
    private func peopleSection(_ detail: TournamentDetail, isPreview: Bool) -> some View {
        let tournament = detail.tournament
        let organiser = Tombstone.displayName(tournament.organizerName, deleted: tournament.deleted)
        return DetailSection(title: People.peopleSection) {
            GlassCard {
                VStack(spacing: 0) {
                    PeopleSummaryRow(title: People.organisedByRow,
                                     names: [organiser],
                                     detail: organiser,
                                     detailMark: tournament.deleted == true ? Tombstone.symbol : nil,
                                     destination: viewModel.permissions.organizerProfile,
                                     identifier: AccessibilityIdentifiers.peopleHostingRow)
                    Divider()
                    // The loaded roster's registered count; the preview's own count stands in until the fetch answers.
                    PeopleSummaryRow(title: tournament.isTeam ? Copy.teamsSection : Copy.playersSection,
                                     names: detail.registeredEntries.map(\.name),
                                     detail: "\(isPreview ? tournament.entryCount : detail.registeredEntries.count)",
                                     destination: entriesDestination(tournament, isPreview: isPreview),
                                     identifier: AccessibilityIdentifiers.peopleGoingRow)
                }
            }
        }
    }

    /// The full list opens for signed-in callers once the entries are in; a preview has nothing to show yet.
    private func entriesDestination(_ tournament: Tournament, isPreview: Bool) -> TournamentPeopleDestination? {
        guard viewModel.permissions.showsEntries, !isPreview else { return nil }
        return TournamentPeopleDestination(destination: tournament.destination)
    }

    @ViewBuilder private func aboutSection(_ tournament: Tournament) -> some View {
        if let description = tournament.description {
            DetailSection(title: People.aboutSection) {
                GlassCard {
                    Text(description).font(.body)
                }
            }
        }
    }

    /// Chat and invite as quiet circles, the enter/leave control as the primary; nothing mounts for a guest, who has
    /// nothing to do here.
    @ViewBuilder var actionBar: some View {
        let permissions = viewModel.permissions
        if permissions.showsActionRow || viewModel.participation != .hidden {
            DetailActionBar {
                if permissions.canOpenChat {
                    Button {
                        Task { await viewModel.openChat() }
                    } label: {
                        Image(systemName: DesignTokens.Symbols.chat)
                    }
                    .lilyGlassIconButton()
                    .accessibilityLabel(AppBranding.Groups.openChat)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentActionChat)
                }
                if permissions.canInvite {
                    Button {
                        presentedSheet = .invite
                    } label: {
                        Image(systemName: DesignTokens.Symbols.invite)
                    }
                    .lilyGlassIconButton()
                    .accessibilityLabel(AppBranding.Groups.invite)
                    .accessibilityIdentifier(AccessibilityIdentifiers.tournamentActionInvite)
                }
            } primary: {
                primaryControl
            }
        }
    }

    /// The one thing the caller can do, as `TournamentParticipation` decides it; the states with nothing to do read
    /// why in the bar's notice, the organiser theirs once registration closed.
    @ViewBuilder private var primaryControl: some View {
        switch viewModel.participation {
        case .hidden:
            EmptyView()
        case .join:
            BusyButton(Copy.join, isBusy: viewModel.isBusy) { await viewModel.join() }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentJoin)
        case .createTeam:
            Button(Copy.createTeam) { presentedSheet = .teamName }
                .lilyProminentButton()
                .disabled(viewModel.isBusy)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentCreateTeam)
        case .leave:
            Button(Copy.leave) { confirmation = .leave }
                .lilyGlassButton()
                .disabled(viewModel.isBusy)
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentLeave)
        case .entered:
            DetailBarNotice(text: Copy.enteredNotice)
        case .registrationClosed:
            DetailBarNotice(text: viewModel.role.isOrganizer ? Copy.organizingNotice : Copy.registrationClosed)
        case .full:
            BusyButton(Copy.full, isBusy: viewModel.isBusy)
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.tournamentJoin)
        }
    }

    /// Where the bracket and matches will be while the fetch is out: a spinner, or Try again once the fetch failed,
    /// in the shared slot so the content below keeps its place.
    @ViewBuilder var loadingSlot: some View {
        TournamentSegmentSlot {
            if viewModel.previewLoadFailed {
                Button(AppBranding.Groups.tryAgain) { Task { await viewModel.load() } }
                    .lilyGlassButton(sizing: .fitted)
            } else {
                ProgressView()
            }
        }
        // A container's identifier would otherwise stamp every child; Try again keeps its own element.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentLoading)
    }

    /// The bracket's columns start where the readable column does: the detail's margin on a phone, further in on a
    /// wide screen.
    private var bracketInset: CGFloat {
        let margin = DesignTokens.Layout.detailMargin
        return max(margin, (contentWidth - DesignTokens.Layout.readableWidth) / 2 + margin)
    }

    func sectionPicker(_ tournament: Tournament) -> some View {
        Picker(Copy.tournament, selection: $section) {
            ForEach(TournamentDetailSection.allCases, id: \.self) { Text($0.title(for: tournament)).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(AccessibilityIdentifiers.tournamentSection)
    }

    @ViewBuilder func segment(_ detail: TournamentDetail) -> some View {
        switch section {
        case .results where detail.tournament.format.drawsBracket && !detail.matches.isEmpty:
            // `BracketView` undoes the margin itself and scrolls edge to edge; only its inset follows the column.
            results(detail).padding(.horizontal, DesignTokens.Layout.detailMargin)
        case .results, .matches:
            results(detail).inReadableColumn()
        }
    }

    private func results(_ detail: TournamentDetail) -> some View {
        TournamentResultsSegment(showsMatches: section == .matches,
                                 detail: detail,
                                 onSelect: { presentedSheet = .match(id: $0.id) },
                                 bracketInset: bracketInset)
    }
}
