import SwiftUI

/// One item of the inbox as a system card on the surface colour (a plain fill, never glass: the list draws many at
/// once): an invite with Accept / Decline while it is open and its status once it is not, or a game reminder that
/// opens the game. A kind this build cannot draw renders nothing.
struct InboxItemRow: View {
    let item: InboxItem
    let viewModel: InboxViewModel

    var body: some View {
        if let invite = item.invite {
            InviteCard(item: item, invite: invite, viewModel: viewModel)
        } else if let reminder = item.reminder {
            ReminderCard(item: item, reminder: reminder, viewModel: viewModel)
        }
    }
}

private struct InviteCard: View {
    let item: InboxItem
    let invite: InvitePayload
    let viewModel: InboxViewModel

    private typealias Copy = AppBranding.Inbox
    /// The `String(format:)` token the names replace in `invitedYouFormat`.
    private static let nameToken = "%@"

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            AvatarCircle(initials: invite.groupName.initials,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .lilySecondary,
                         tintOpacity: DesignTokens.Opacity.secondaryGlassTint)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                inviteText.font(.body)
                Label(invite.groupVisibility.displayName, systemImage: invite.groupVisibility.symbolName)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                if let status = invite.statusCaption(now: viewModel.now()) {
                    Text(status)
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                } else {
                    actions
                }
            }
        }
        .inboxCard()
        // A container first: an identifier on a bare stack is stamped on every element inside it, the buttons included.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.inboxItem(item.id))
    }

    /// "**Noor** invited you to **Climbing Buddies**": the names in bold, the words between from the format string.
    private var inviteText: Text {
        let pieces = Copy.invitedYouFormat.components(separatedBy: Self.nameToken)
        guard pieces.count == 3 else {
            return Text(verbatim: Copy.invitedYou(inviter: invite.inviterName, group: invite.groupName))
        }
        var text = AttributedString(pieces[0])
        text += Self.emphasised(invite.inviterName)
        text += AttributedString(pieces[1])
        text += Self.emphasised(invite.groupName)
        text += AttributedString(pieces[2])
        return Text(text)
    }

    private static func emphasised(_ name: String) -> AttributedString {
        var text = AttributedString(name)
        text.inlinePresentationIntent = .stronglyEmphasized
        return text
    }

    /// Regular-size capsules: inside a card the large ones read as a screen's call to action and dwarf its text.
    private var actions: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Button(Copy.accept) { Task { await viewModel.accept(item) } }
                .lilyProminentButton(sizing: .fitted, controlSize: .regular)
                .accessibilityIdentifier(AccessibilityIdentifiers.inboxAccept(item.id))
            Button(Copy.decline) { Task { await viewModel.decline(item) } }
                .lilyGlassButton(sizing: .fitted, controlSize: .regular, labelColor: .lilyInk)
                .accessibilityIdentifier(AccessibilityIdentifiers.inboxDecline(item.id))
            if viewModel.isBusy(item) {
                ProgressView()
                    .controlSize(.regular)
                    .accessibilityHidden(true)
            }
        }
        .disabled(viewModel.isBusy(item))
        .padding(.top, DesignTokens.Spacing.xs)
    }
}

private struct ReminderCard: View {
    let item: InboxItem
    let reminder: ReminderPayload
    let viewModel: InboxViewModel

    private typealias Copy = AppBranding.Inbox

    var body: some View {
        Button {
            Task { await viewModel.openEvent(for: item) }
        } label: {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                AvatarCircle(initials: "", systemImage: DesignTokens.Symbols.game, size: DesignTokens.Layout.avatarMedium)
                details
                Spacer(minLength: DesignTokens.Spacing.sm)
                Image(systemName: DesignTokens.Symbols.chevron)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Copy.openGame)
            }
            .inboxCard()
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isBusy(item))
        .accessibilityIdentifier(AccessibilityIdentifiers.inboxItem(item.id))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(Copy.reminderTitle)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: reminder.title)
                .font(.body.weight(.semibold))
            Label(reminder.locationName, systemImage: DesignTokens.Symbols.location)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label(reminder.startsAtCaption(now: viewModel.now()), systemImage: DesignTokens.Symbols.time)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let groupName = reminder.groupName {
                Text(AppBranding.Groups.hostedIn(groupName: groupName))
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.leading)
    }
}

private extension View {
    /// The card of an inbox item: the surface colour in the bubble radius, full width, ink text like a bubble's.
    func inboxCard() -> some View {
        padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.lilyInk)
            .background(Color.lilySurface, in: .rect(cornerRadius: DesignTokens.Radius.bubble))
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    let viewModel = dependencies.makeInboxViewModel()
    ContentScreen {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(MockInboxFixtures.make(now: .now)) { InboxItemRow(item: $0, viewModel: viewModel) }
        }
        .padding()
    }
}
