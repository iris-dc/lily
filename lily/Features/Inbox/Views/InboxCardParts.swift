import SwiftUI

/// The pieces every inbox card is built from, so the group and tournament invites and the game and match reminders
/// share one look: the card itself, the bold invitation sentence, the Accept / Decline row and the tappable card with
/// a chevron.
extension View {
    /// The card of an inbox item: the surface colour in the bubble radius, full width, ink text like a bubble's (a
    /// plain fill, never glass: the list draws many at once).
    func inboxCard() -> some View {
        padding(DesignTokens.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Color.lilyInk)
            .background(Color.lilySurface, in: .rect(cornerRadius: DesignTokens.Radius.bubble))
    }
}

/// "**Noor** invited you to **Climbing Buddies**": the names in bold, the words around them from the copy, so the bold
/// runs land wherever a language puts them.
struct InviteSentence: View {
    let inviter: String
    let target: String

    /// Stand-ins formatted into the copy in place of the names.
    private static let inviterMarker = "\u{FFFC}1"
    private static let targetMarker = "\u{FFFC}2"

    var body: Text {
        var text = AttributedString(AppBranding.Inbox.invitedYou(inviter: Self.inviterMarker, group: Self.targetMarker))
        Self.replace(Self.inviterMarker, with: inviter, in: &text)
        Self.replace(Self.targetMarker, with: target, in: &text)
        return Text(text)
    }

    private static func replace(_ marker: String, with name: String, in text: inout AttributedString) {
        guard let range = text.range(of: marker) else { return }
        var emphasised = AttributedString(name)
        emphasised.inlinePresentationIntent = .stronglyEmphasized
        text.replaceSubrange(range, with: emphasised)
    }
}

/// An invite's card: the mark, the sentence, a detail line, then Accept / Decline while it is open and its status once
/// it is not. A container first: an identifier on a bare stack is stamped on every element inside it, the buttons
/// included.
struct InboxInviteCard<Mark: View, Details: View>: View {
    let item: InboxItem
    let viewModel: InboxViewModel
    let inviter: String
    let target: String
    /// What an answered or lapsed invite says in place of its buttons; `nil` while it is still open.
    let status: String?
    @ViewBuilder let mark: () -> Mark
    @ViewBuilder let details: () -> Details

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            mark()
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                InviteSentence(inviter: inviter, target: target).font(.body)
                details()
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                if let status {
                    Text(status)
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                } else {
                    InboxInviteActions(item: item, viewModel: viewModel)
                }
            }
        }
        .inboxCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityIdentifiers.inboxItem(item.id))
    }
}

/// Accept and Decline under an open invite, regular-size capsules (inside a card the large ones read as a screen's
/// call to action and dwarf its text), with a spinner while an answer is out.
struct InboxInviteActions: View {
    let item: InboxItem
    let viewModel: InboxViewModel

    private typealias Copy = AppBranding.Inbox

    var body: some View {
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

/// A card that opens something on a tap (a reminder's game or tournament): the glyph, the details and a chevron whose
/// accessibility label names the destination.
struct InboxOpenCard<Details: View>: View {
    let item: InboxItem
    let isBusy: Bool
    let symbol: String
    let openLabel: String
    @ViewBuilder let details: () -> Details
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                AvatarCircle(initials: "", systemImage: symbol, size: DesignTokens.Layout.avatarMedium)
                details()
                    .multilineTextAlignment(.leading)
                Spacer(minLength: DesignTokens.Spacing.sm)
                Image(systemName: DesignTokens.Symbols.chevron)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(openLabel)
            }
            .inboxCard()
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .disabled(isBusy)
        .accessibilityIdentifier(AccessibilityIdentifiers.inboxItem(item.id))
    }
}
