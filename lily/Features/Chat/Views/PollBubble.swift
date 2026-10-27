import SwiftUI

/// A poll in its bubble: the question, how it votes, a pill per option (`PollOptionPill`) and a line with the voters'
/// count. Before the caller voted a tap on a pill votes, with several answers it ticks the pill and Vote sends the
/// ticks; once they voted the pills fill to their shares, theirs ticked, and View votes opens a public poll's voters.
/// Every state shares one layout, so the bubble keeps its height and the transcript stands still; what the poll's
/// change moves (the fills, the numbers, the ticks) animates in place. Taking a vote back is in the long press.
struct PollBubble: View {
    let poll: Poll
    let own: Bool
    var isEnabled = true
    var onVote: ([String]) -> Void = { _ in }
    var onShowVoters: () -> Void = {}
    @State private var ticked: Set<String> = []

    private typealias Copy = AppBranding.Chat.Polls

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(verbatim: poll.question)
                    .fontWeight(.semibold)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(ink.secondary)
            }
            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(Array(poll.options.enumerated()), id: \.element.id) { index, option in
                    PollOptionPill(option: option, display: PollOptionDisplay(option, in: poll, ticked: ticked), own: own) {
                        choose(option)
                    }
                    .accessibilityIdentifier(AccessibilityIdentifiers.pollOption(index))
                }
            }
            .disabled(poll.hasVoted)
            footer
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(!isEnabled)
        .animation(.spring(duration: DesignTokens.Duration.normal), value: poll)
        .onChange(of: poll.myVotes) { ticked = [] }
    }

    private var caption: String {
        let kind = poll.isAnonymous ? Copy.anonymousPoll : Copy.publicPoll
        return poll.allowsMultipleAnswers
            ? [kind, Copy.multipleAnswers].joined(separator: AppBranding.Events.captionSeparator)
            : kind
    }

    private var ink: BubbleInk { BubbleInk(own: own) }

    private func choose(_ option: Poll.Option) {
        guard poll.allowsMultipleAnswers else {
            onVote([option.id])
            return
        }
        withAnimation(.spring(duration: DesignTokens.Duration.fast)) {
            if ticked.contains(option.id) { ticked.remove(option.id) } else { ticked.insert(option.id) }
        }
    }

    /// The voters' count and, at the trailing edge, Vote or View votes when the poll offers one; one height whichever
    /// shows, so the bubble's does not change with it. The count rolls its digits from one number to the next, and
    /// crossfades to and from "No votes yet", which has no digits to roll (the morph left ghosts of the words).
    private var footer: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(poll.totalVoters == 0 ? Copy.noVotesYet : Copy.voterCount(poll.totalVoters))
                .font(.footnote)
                .foregroundStyle(ink.secondary)
                .contentTransition(poll.totalVoters > 1 ? .numericText() : .opacity)
                .accessibilityIdentifier(AccessibilityIdentifiers.pollTotal)
            Spacer(minLength: 0)
            footerAction
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderless)
                .tint(ink.accent)
        }
        .frame(minHeight: DesignTokens.Layout.pollFooterHeight)
    }

    @ViewBuilder private var footerAction: some View {
        if poll.allowsMultipleAnswers, !poll.hasVoted {
            Button(Copy.vote) { onVote(poll.options.map(\.id).filter(ticked.contains)) }
                .tappableLabel(minHeight: DesignTokens.Layout.pollFooterHeight)
                .disabled(ticked.isEmpty)
                .accessibilityIdentifier(AccessibilityIdentifiers.pollVote)
        } else if poll.hasVoted, !poll.isAnonymous {
            Button(Copy.viewVotes, action: onShowVoters)
                .tappableLabel(minHeight: DesignTokens.Layout.pollFooterHeight)
                .accessibilityIdentifier(AccessibilityIdentifiers.pollVoters)
        }
    }
}
