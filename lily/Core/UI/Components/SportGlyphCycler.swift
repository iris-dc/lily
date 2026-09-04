import SwiftUI

/// Hero ornament: cycles through sport symbols with a draw-on animation inside a glass badge.
struct SportGlyphCycler: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let sports = SportType.allCases

    var body: some View {
        TimelineView(.periodic(from: .now, by: DesignTokens.Duration.sportGlyphCycle)) { context in
            let sport = reduceMotion ? sports[0] : current(at: context.date)
            Image(systemName: sport.symbolName)
                .font(.system(size: DesignTokens.Layout.heroGlyphSize, weight: .medium))
                .foregroundStyle(Color.lilyAccent)
                .id(sport)
                .transition(.symbolEffect(.drawOn))
                .animation(.smooth(duration: DesignTokens.Duration.slow), value: sport)
        }
        .frame(width: DesignTokens.Layout.heroGlyphBadge, height: DesignTokens.Layout.heroGlyphBadge)
        .glassEffect(.regular, in: .circle)
        .accessibilityHidden(true)
    }

    private func current(at date: Date) -> SportType {
        let step = Int(date.timeIntervalSinceReferenceDate / DesignTokens.Duration.sportGlyphCycle)
        return sports[step % sports.count]
    }
}
