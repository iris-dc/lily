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

/// The join slide's screen: an event's detail down to its Join button, with a ring pulsing where the finger goes. The
/// Join sits at the bottom of the frame as on the real detail: the facts card takes whatever height is left (a live
/// event without a price or a level is shorter than the fixture), through a flexible frame rather than a `Spacer`, which
/// would add a stack gap of its own; a frame too short for the screen crops the top instead.
struct IntroDetailScreen: View {
    let event: SportEvent

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            EventTypeChip(type: event.type)
            ScreenTitle(text: event.title, subtitle: AppBranding.hostedByTitle(for: event.hostName))
            EventFactsCard(event: event)
                .frame(maxHeight: .infinity, alignment: .top)
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
/// three and no segment picker, so the bracket stays within the frame on a 6.3-inch phone; a shorter phone fades the
/// bracket's bottom like the list's.
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

/// A ring growing out of the Join button and fading, resting, and again, while its slide is on screen: the "tap here"
/// of the join slide. Every frame is read off a clock through `TapPulseCurve`, at the aurora's cadence, so the ring's
/// growth and fade cannot drift apart: a `repeatForever` animation here had its scale stall while the opacity kept
/// cycling. The pager holds every slide, so the clock starts when the ring itself scrolls into view, not on
/// `onAppear`. Nothing under Reduce Motion or with the aurora frozen.
private struct TapPulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.auroraFrozen) private var auroraFrozen
    /// When the ring scrolled into view; `nil` while it is off screen, which also pauses the clock.
    @State private var startedAt: Date?

    var body: some View {
        if !reduceMotion && !auroraFrozen {
            TimelineView(.animation(minimumInterval: DesignTokens.Aurora.frameInterval, paused: startedAt == nil)) { context in
                ring(TapPulseCurve.intro.frame(elapsed: startedAt.map(context.date.timeIntervalSince) ?? 0))
            }
            .onScrollVisibilityChange(threshold: DesignTokens.Layout.introPulseVisibilityThreshold) { isVisible in
                startedAt = isVisible ? .now : nil
            }
        }
    }

    private func ring(_ frame: TapPulseCurve.Frame) -> some View {
        Circle()
            .strokeBorder(Color.white, lineWidth: DesignTokens.Layout.introPulseLineWidth)
            .frame(width: DesignTokens.Layout.controlHeight, height: DesignTokens.Layout.controlHeight)
            .scaleEffect(frame.scale)
            .opacity(frame.opacity)
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
