import SwiftUI

/// One match, from its cell: both sides and where the match stands, then what the caller may do (`MatchActions`): a
/// side types and reports a score, or confirms or disputes the score the other side reported; the organiser records a
/// score (final at once), confirms a reported one, gives a walkover to either side or sets the time and place
/// (`MatchScheduleView`, pushed in this sheet's stack). Everyone else reads. Closes once a write went through; the
/// detail behind it already shows the answer.
struct MatchSheet: View {
    let viewModel: TournamentDetailViewModel
    let matchID: String
    let errorCenter: ErrorCenter
    @State private var scoreA = ""
    @State private var scoreB = ""
    @Environment(\.dismiss) private var dismiss

    private typealias Copy = AppBranding.Tournaments.Match

    /// The match as the detail holds it now; a write's answer changes it under the sheet.
    private var match: TournamentMatch? { viewModel.detail?.match(id: matchID) }
    private var permitsDraws: Bool { viewModel.tournament?.permitsDraws ?? false }

    var body: some View {
        NavigationStack {
            ContentScreen {
                if let match {
                    content(match, actions: viewModel.actions(for: match))
                }
            }
            .navigationTitle(Copy.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppBranding.Groups.Invite.done) { dismiss() }
                        .disabled(viewModel.isBusy)
                }
            }
            .tint(Color.lilyAccent)
        }
        .presentationDetents([.medium, .large])
        .lilyFormSheet()
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(viewModel.isBusy)
        // A sheet is drawn above the root, so the shared popup mounted there would sit behind this one.
        .errorPopup(errorCenter)
        .onAppear { seedScores() }
    }

    private func content(_ match: TournamentMatch, actions: MatchActions) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                MatchCell(match: match, viewModel: viewModel, showsDetails: true)
                if let notice = notice(for: match, actions: actions) {
                    Text(notice)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if actions.takesScore {
                    scoreFields(match)
                }
                actionButtons(match, actions: actions)
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }

    /// What the caller should know before acting: the other side's report, their own report waiting, or a dispute.
    private func notice(for match: TournamentMatch, actions: MatchActions) -> String? {
        if match.isOpenDispute { return Copy.disputedNotice }
        if actions.awaitsOtherSide { return Copy.awaitingOtherSide }
        guard actions.canConfirm, let scoreA = match.scoreA, let scoreB = match.scoreB else { return nil }
        let reporter = viewModel.detail?.entry(containing: match.reportedBy)?.name ?? viewModel.entryName(match.entryAId)
        return Copy.reported(by: reporter, score: Copy.score(scoreA, scoreB))
    }

    private func scoreFields(_ match: TournamentMatch) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.lg) {
                scoreField(viewModel.entryName(match.entryAId), text: $scoreA, identifier: AccessibilityIdentifiers.matchScoreA)
                Text(verbatim: Copy.scoreSeparator)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, DesignTokens.Spacing.md)
                scoreField(viewModel.entryName(match.entryBId), text: $scoreB, identifier: AccessibilityIdentifiers.matchScoreB)
            }
            if isDisallowedDraw {
                Text(Copy.drawsNotAllowed)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(Color.lilyAccent)
            }
        }
    }

    private func scoreField(_ name: String, text: Binding<String>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(name)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            TextField(String(AppConfig.Tournaments.scoreRange.lowerBound), text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .lilyField()
                .frame(width: DesignTokens.Layout.scoreFieldWidth)
                .accessibilityIdentifier(identifier)
        }
    }

    @ViewBuilder private func actionButtons(_ match: TournamentMatch, actions: MatchActions) -> some View {
        if actions.canRecord {
            scoreButton(Copy.record, match: match, identifier: AccessibilityIdentifiers.matchRecord)
        } else if actions.canReport {
            scoreButton(Copy.report, match: match, identifier: AccessibilityIdentifiers.matchReport)
        }
        if actions.canConfirm {
            actionButton(Copy.confirm, identifier: AccessibilityIdentifiers.matchConfirm) { await viewModel.confirm(match) }
                .lilyProminentButton()
        }
        if actions.canDispute {
            actionButton(Copy.dispute, identifier: AccessibilityIdentifiers.matchDispute) { await viewModel.dispute(match) }
                .lilyGlassButton()
        }
        if actions.canWalkover {
            walkoverMenu(match)
        }
        if actions.canSchedule {
            NavigationLink {
                MatchScheduleView(viewModel: viewModel, match: match) { dismiss() }
            } label: {
                Label(AppBranding.Tournaments.Schedule.title, systemImage: DesignTokens.Symbols.scheduled)
            }
            .lilyGlassButton(labelColor: .lilyInk)
            .disabled(viewModel.isBusy)
            .accessibilityIdentifier(AccessibilityIdentifiers.matchSchedule)
        }
    }

    /// Report or Record: enabled once both scores parse and the pair is allowed.
    private func scoreButton(_ title: String, match: TournamentMatch, identifier: String) -> some View {
        actionButton(title, identifier: identifier) {
            guard let scores = parsedScores else { return false }
            return await viewModel.report(match, scoreA: scores.a, scoreB: scores.b)
        }
        .lilyProminentButton()
        .disabled(!canSubmitScore)
    }

    /// A write that closes the sheet when it went through; the detail behind already shows the answer.
    private func actionButton(_ title: String, identifier: String, _ write: @escaping () async -> Bool) -> some View {
        Button {
            Task { if await write() { dismiss() } }
        } label: {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(title)
                if viewModel.isBusy {
                    ProgressView()
                        .controlSize(.regular)
                        .accessibilityHidden(true)
                }
            }
        }
        .disabled(viewModel.isBusy)
        .accessibilityIdentifier(identifier)
    }

    /// The organiser picks who wins a match that was not played.
    private func walkoverMenu(_ match: TournamentMatch) -> some View {
        Menu {
            ForEach([match.entryAId, match.entryBId].compactMap { $0 }, id: \.self) { entryID in
                Button(Copy.walkoverWinner(viewModel.entryName(entryID))) {
                    Task { if await viewModel.walkover(match, winnerEntryID: entryID) { dismiss() } }
                }
                .accessibilityIdentifier(AccessibilityIdentifiers.matchWalkoverWinner(entryID))
            }
        } label: {
            Label(Copy.walkover, systemImage: DesignTokens.Symbols.walkover)
        }
        .menuStyle(.button)
        .lilyGlassButton(labelColor: .lilyInk)
        .disabled(viewModel.isBusy)
        .accessibilityIdentifier(AccessibilityIdentifiers.matchWalkover)
    }

    private var parsedScores: (a: Int, b: Int)? {
        let range = AppConfig.Tournaments.scoreRange
        guard let a = Int(scoreA), let b = Int(scoreB), range.contains(a), range.contains(b) else { return nil }
        return (a, b)
    }

    private var isDisallowedDraw: Bool {
        guard let scores = parsedScores else { return false }
        return scores.a == scores.b && !permitsDraws
    }

    private var canSubmitScore: Bool { parsedScores != nil && !isDisallowedDraw }

    /// A reported score is the starting point for the organiser's record or a side's correction.
    private func seedScores() {
        scoreA = match?.scoreA.map(String.init) ?? ""
        scoreB = match?.scoreB.map(String.init) ?? ""
    }
}
