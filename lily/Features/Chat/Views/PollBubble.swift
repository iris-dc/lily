import SwiftUI

/// A poll in its bubble, drawn as Telegram draws one: the question, whether the poll is anonymous and takes several
/// answers, then the options. Before the caller voted a tap on an option votes; with multiple answers it ticks, and
/// Vote sends the ticks. Once they voted, each option shows its share as a number and a bar, theirs marked, and the
/// voters' count sits under them with View votes for a public poll. Taking a vote back is in the long press.
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
                    .foregroundStyle(secondary)
            }
            ForEach(Array(poll.options.enumerated()), id: \.element.id) { index, option in
                optionRow(option)
                    .accessibilityIdentifier(AccessibilityIdentifiers.pollOption(index))
            }
            footer
        }
        .frame(minWidth: DesignTokens.Layout.pollMinWidth, alignment: .leading)
        .disabled(!isEnabled)
        .onChange(of: poll.myVotes) { ticked = [] }
    }

    private var caption: String {
        let kind = poll.isAnonymous ? Copy.anonymousPoll : Copy.publicPoll
        return poll.allowsMultipleAnswers ? "\(kind) · \(Copy.multipleAnswers)" : kind
    }

    private var secondary: Color { own ? Color.white.opacity(DesignTokens.Opacity.secondaryOnAccent) : .secondary }

    @ViewBuilder private func optionRow(_ option: Poll.Option) -> some View {
        if poll.hasVoted {
            PollResultRow(option: option, share: poll.share(of: option), isMine: poll.myVotes.contains(option.id), own: own)
        } else {
            Button {
                choose(option)
            } label: {
                Label {
                    Text(verbatim: option.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } icon: {
                    Image(systemName: symbol(for: option))
                        .foregroundStyle(ticked.contains(option.id) ? (own ? Color.white : Color.lilyAccent) : secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(ticked.contains(option.id) ? .isSelected : [])
        }
    }

    private func symbol(for option: Poll.Option) -> String {
        if poll.allowsMultipleAnswers {
            return ticked.contains(option.id) ? DesignTokens.Symbols.pollTicked : DesignTokens.Symbols.pollTick
        }
        return DesignTokens.Symbols.pollChoice
    }

    private func choose(_ option: Poll.Option) {
        guard poll.allowsMultipleAnswers else {
            onVote([option.id])
            return
        }
        if ticked.contains(option.id) { ticked.remove(option.id) } else { ticked.insert(option.id) }
    }

    private var footer: some View {
        HStack {
            Text(poll.totalVoters == 0 ? Copy.noVotesYet : Copy.voterCount(poll.totalVoters))
                .font(.caption)
                .foregroundStyle(secondary)
                .accessibilityIdentifier(AccessibilityIdentifiers.pollTotal)
            Spacer(minLength: DesignTokens.Spacing.sm)
            if poll.allowsMultipleAnswers, !poll.hasVoted {
                Button(Copy.vote) { onVote(poll.options.map(\.id).filter(ticked.contains)) }
                    .buttonStyle(.borderless)
                    .tappableLabel()
                    .disabled(ticked.isEmpty)
                    .accessibilityIdentifier(AccessibilityIdentifiers.pollVote)
            } else if poll.hasVoted, !poll.isAnonymous {
                Button(Copy.viewVotes, action: onShowVoters)
                    .buttonStyle(.borderless)
                    .tappableLabel()
                    .accessibilityIdentifier(AccessibilityIdentifiers.pollVoters)
            }
        }
        .font(.caption.weight(.semibold))
        .tint(own ? Color.white : Color.lilyAccent)
    }
}

/// One option of a poll the caller voted in: its share, its text, a mark when it is theirs, and the bar.
private struct PollResultRow: View {
    let option: Poll.Option
    let share: Double
    let isMine: Bool
    let own: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Text(share.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .frame(width: DesignTokens.Layout.pollShareWidth, alignment: .leading)
                Text(verbatim: option.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isMine {
                    Image(systemName: DesignTokens.Symbols.pollChosen)
                        .font(.caption)
                        .accessibilityLabel(AppBranding.Chat.Polls.chosen)
                }
            }
            ZStack(alignment: .leading) {
                Capsule().fill(fill.opacity(DesignTokens.Opacity.pollBarTrack))
                Capsule().fill(fill).scaleEffect(x: share, y: 1, anchor: .leading)
            }
            .frame(height: DesignTokens.Layout.pollBarHeight)
            .padding(.leading, DesignTokens.Layout.pollShareWidth + DesignTokens.Spacing.xs)
            .animation(.easeOut(duration: DesignTokens.Duration.normal), value: share)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isMine ? .isSelected : [])
    }

    private var fill: Color { own ? Color.white : Color.lilyAccent }
}
