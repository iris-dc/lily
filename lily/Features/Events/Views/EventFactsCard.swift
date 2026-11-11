import SwiftUI

/// Time, place, price and level, then how full it is: the facts card of the event detail, which the intro's detail
/// miniature draws too. Price only when the game costs something, level only when set.
struct EventFactsCard: View {
    let event: SportEvent

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Label {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text(event.startsAt, format: LilyTheme.DateStyles.dateTime)
                        if let untilText {
                            Text(untilText)
                                .font(LilyTheme.Fonts.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: DesignTokens.Symbols.time)
                }
                Label(event.locationName, systemImage: DesignTokens.Symbols.location)
                if !event.isFree {
                    Label(AppBranding.Events.perPerson(event.priceText), systemImage: DesignTokens.Symbols.price)
                }
                // A level this build cannot name is left out like none: the row would read "Any level level".
                if let level = event.skillLevel?.ifKnown {
                    Label(AppBranding.Events.level(level.displayName), systemImage: DesignTokens.Symbols.level)
                }
                EntriesBar(event: event)
            }
            .labelStyle(.iconColumn)
        }
    }

    /// "Until 20:30" when the game ends on the start's own day, the full date otherwise; nothing without a finish.
    private var untilText: String? {
        guard let endsAt = event.endsAt else { return nil }
        let sameDay = Calendar.current.isDate(endsAt, inSameDayAs: event.startsAt)
        return AppBranding.Events.until(endsAt.formatted(sameDay ? LilyTheme.DateStyles.time : LilyTheme.DateStyles.dateTime))
    }
}
