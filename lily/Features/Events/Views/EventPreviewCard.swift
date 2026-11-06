import SwiftUI

/// One event as a card under the map's selected pin: the sport's filled mark, the title over the group (or the place),
/// the distance and the price at the trailing edge, and a footer with the start in a capsule and the spots beside a
/// short meter. At accessibility type sizes each row becomes a column, so the words get the full width instead of one
/// truncated line.
struct EventPreviewCard: View {
    /// Where the card stands: alone over the map it is its own glass; inside the many-events panel it is an ink wash
    /// on the panel's glass, since a second glass would muddy the first.
    enum Surface {
        case glass
        case inset
    }

    let event: SportEvent
    /// Optional trailing detail such as distance.
    var detail: String?
    var surface: Surface = .glass
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isRow: Bool { !typeSize.isAccessibilitySize }
    private var lineLimit: Int { isRow ? 1 : DesignTokens.Layout.accessibilityPreviewLines }
    /// The title may take a second line rather than be cut: inside the many-events panel the card is a little narrower.
    private var titleLineLimit: Int {
        isRow ? DesignTokens.Layout.mapCardTitleLines : DesignTokens.Layout.accessibilityPreviewLines
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            header
            footer
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(CardSurface(surface: surface))
        .contentShape(.rect(cornerRadius: DesignTokens.Radius.md))
    }

    private var header: some View {
        let layout = isRow
            ? AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.md))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
        return layout {
            AvatarCircle(systemImage: event.type.symbolName, size: DesignTokens.Layout.mapCardMarkSize, tint: .sport)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(event.title)
                    .font(LilyTheme.Fonts.itemTitle)
                    .foregroundStyle(Color.lilyInk)
                    .lineLimit(titleLineLimit)
                    // Without it the title truncates on one line instead of taking its second.
                    .fixedSize(horizontal: false, vertical: true)
                // The group when there is one, the place otherwise, so every card is the same two lines tall.
                Label(event.group?.name ?? event.locationName,
                      systemImage: event.group == nil ? DesignTokens.Symbols.location : DesignTokens.Symbols.groups)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(lineLimit)
            }
            // The column takes all the width the mark and the trailing facts leave: beside a `Spacer` a title that may
            // wrap was offered only half of it and broke after its first word.
            .frame(maxWidth: .infinity, alignment: .leading)
            trailingFacts
        }
    }

    private var trailingFacts: some View {
        VStack(alignment: isRow ? .trailing : .leading, spacing: DesignTokens.Spacing.xs) {
            if let detail {
                Text(detail)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
            }
            if !event.isFree {
                Text(event.priceText)
                    .font(LilyTheme.Fonts.caption.weight(.semibold))
                    .foregroundStyle(Color.lilyInk)
            }
        }
        .fixedSize()
    }

    private var footer: some View {
        let layout = isRow
            ? AnyLayout(HStackLayout(spacing: DesignTokens.Spacing.sm))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.sm))
        return layout {
            startCapsule
            HStack(spacing: DesignTokens.Spacing.xs) {
                if event.playerLimit.hasCapacity {
                    CapacityMeter(event: event)
                        .frame(width: DesignTokens.Layout.mapCardMeterWidth)
                }
                Text(event.availabilityText)
                    .font(LilyTheme.Fonts.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(lineLimit)
            }
        }
    }

    /// "in 3 hr." in ink on a faint ink capsule, the clock in the accent: the one fact the eye looks for first.
    private var startCapsule: some View {
        Label {
            Text(event.startsAt.formatted(
                .relative(presentation: .named, unitsStyle: .abbreviated).locale(AppLocale.locale)))
                .foregroundStyle(Color.lilyInk)
        } icon: {
            Image(systemName: DesignTokens.Symbols.time)
                .foregroundStyle(Color.lilyAccent)
        }
        .font(LilyTheme.Fonts.caption)
        .lineLimit(1)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(Color.lilyInk.opacity(DesignTokens.Opacity.mapCardCapsuleFill), in: .capsule)
        .fixedSize()
    }
}

/// The card's own glass, or the ink wash it takes inside the many-events panel.
private struct CardSurface: ViewModifier {
    let surface: EventPreviewCard.Surface

    func body(content: Content) -> some View {
        switch surface {
        case .glass:
            content.glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.md))
        case .inset:
            content.background(Color.lilyInk.opacity(DesignTokens.Opacity.mapPanelCardWash),
                               in: .rect(cornerRadius: DesignTokens.Radius.md))
        }
    }
}
