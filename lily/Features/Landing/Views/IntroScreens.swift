import SwiftUI

/// The events slide's screen: the top of Explore, drawn with the real cards over the events the view model holds (the
/// live preview, or the fixtures while none arrived).
struct IntroExploreScreen: View {
    let events: [SportEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            ScreenTitle(text: AppBranding.exploreTitle)
            ForEach(events) { event in
                EventCard(event: event)
            }
        }
    }
}

/// The join slide's screen: an event's detail down to its Join button, with a ring pulsing where the finger goes.
struct IntroDetailScreen: View {
    let event: SportEvent

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            EventTypeChip(type: event.type)
            ScreenTitle(text: event.title, subtitle: AppBranding.hostedByTitle(for: event.hostName))
            EventFactsCard(event: event)
            Button(AppBranding.joinAction) {}
                .lilyProminentButton()
                .overlay { TapPulse() }
        }
    }
}

/// The groups slide's screen: a group's room where a question, the caller's answer, the game it turned into and a last
/// word lead down to the composer, each drawn the way the chat draws it, the composer at the bottom as in a room.
struct IntroChatScreen: View {
    let eventTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            header
            line(AppBranding.Intro.Chat.question, own: false)
            line(AppBranding.Intro.Chat.answer, own: true)
            Label(AppBranding.Chat.eventCreated(by: IntroFixtures.senderName, title: eventTitle),
                  systemImage: DesignTokens.Symbols.game)
                .font(LilyTheme.Fonts.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
            line(AppBranding.Intro.Chat.followUp, own: false)
            Spacer(minLength: 0)
            composer
        }
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            AvatarCircle(initials: IntroFixtures.groupName.initials,
                         size: DesignTokens.Layout.avatarMedium,
                         tint: .secondary)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(IntroFixtures.groupName).font(LilyTheme.Fonts.cardTitle)
                Text(AppBranding.Groups.members(IntroFixtures.memberCount))
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// One bubble as `MessageBubble` draws the first of a run: another sender's with avatar and name, the caller's alone.
    /// The text keeps its lines: squeezed by a frame shorter than the room, a wrapped bubble would otherwise fold to one
    /// line with an ellipsis instead of the frame cropping the header above it.
    private func line(_ text: String, own: Bool) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            if !own {
                AvatarCircle(initials: IntroFixtures.senderName.initials,
                             size: DesignTokens.Layout.avatarSmall,
                             tint: .secondary)
            }
            VStack(alignment: own ? .trailing : .leading, spacing: DesignTokens.Spacing.xs) {
                if !own {
                    Text(IntroFixtures.senderName)
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: text)
                    .fixedSize(horizontal: false, vertical: true)
                    .bubbleFill(own: own)
            }
        }
        .frame(maxWidth: .infinity, alignment: own ? .trailing : .leading)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.sm) {
            Text(AppBranding.Chat.placeholder)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lilyMultilineField()
            Button {} label: { Image(systemName: DesignTokens.Symbols.send) }
                .lilyIconButton()
        }
    }
}

/// The tournaments slide's screen: the top of a tournament's detail and its bracket, drawn the way the detail draws it
/// (the first round in full, the next column peeking in at the edge as on a phone). Two chips rather than the detail's
/// three and no segment picker: the frame crops at the top, and both took the chips over its edge on a 6.3-inch phone.
struct IntroTournamentScreen: View {
    let detail: TournamentDetail

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                EventTypeChip(type: detail.tournament.type)
                TournamentStatusChip(status: detail.tournament.status)
            }
            ScreenTitle(text: detail.tournament.name,
                        subtitle: AppBranding.Tournaments.organizedBy(name: detail.tournament.organizerName))
            BracketView(detail: detail) { _ in }
        }
    }
}

/// A ring growing out of the Join button and fading, over and over, while its slide is on screen: the "tap here" of
/// the join slide. The pager holds every slide, so the animation follows scroll visibility, not `onAppear`. Nothing
/// under Reduce Motion.
private struct TapPulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    var body: some View {
        if !reduceMotion {
            Circle()
                .strokeBorder(Color.white.opacity(DesignTokens.Opacity.introPulse),
                              lineWidth: DesignTokens.Layout.introPulseLineWidth)
                .frame(width: DesignTokens.Layout.controlHeight, height: DesignTokens.Layout.controlHeight)
                .scaleEffect(isExpanded ? DesignTokens.Layout.introPulseScale : 1)
                .opacity(isExpanded ? 0 : 1)
                .onScrollVisibilityChange(threshold: DesignTokens.Layout.introPulseVisibilityThreshold) { isVisible in
                    setPulsing(isVisible)
                }
        }
    }

    private func setPulsing(_ pulsing: Bool) {
        if pulsing {
            withAnimation(.easeOut(duration: DesignTokens.Duration.introPulsePeriod).repeatForever(autoreverses: false)) {
                isExpanded = true
            }
        } else {
            withAnimation(nil) { isExpanded = false }
        }
    }
}

#Preview("Screens") {
    let events = IntroFixtures.events(now: .now)
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.xl) {
            IntroScreenFrame { IntroExploreScreen(events: events) }.frame(height: 400)
            IntroScreenFrame { IntroDetailScreen(event: events[0]) }.frame(height: 400)
            IntroScreenFrame { IntroChatScreen(eventTitle: events[0].title) }.frame(height: 400)
            IntroScreenFrame { IntroTournamentScreen(detail: IntroFixtures.tournament(now: .now)) }.frame(height: 400)
        }
    }
    .background(Color.lilySurface)
}
