import SwiftUI

/// Time, place, price and level, then how full it is: the facts card of the event detail, which the intro's detail
/// miniature draws too. Price only when the game costs something, level only when set.
struct EventFactsCard: View {
    let event: SportEvent

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                Label {
                    Text(event.startsAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                } icon: {
                    Image(systemName: DesignTokens.Symbols.time)
                }
                Label(event.locationName, systemImage: DesignTokens.Symbols.location)
                if !event.isFree {
                    Label(AppBranding.Events.perPerson(event.priceText), systemImage: DesignTokens.Symbols.price)
                }
                if let level = event.skillLevel {
                    Label(AppBranding.Events.level(level.displayName), systemImage: DesignTokens.Symbols.level)
                }
                CapacityBar(event: event)
            }
            .labelStyle(.iconColumn)
        }
    }
}
