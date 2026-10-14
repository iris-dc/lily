import SwiftUI

/// A titled row of tiles on Explore, Meetup-style: a heading with "See all" and `rows` rows of tiles scrolling together
/// sideways; on a regular width a wrapping grid of the first few instead (`TileGrid`), since a sideways scroll on a
/// screen that wide leaves most of it empty. Draws nothing until there is at least one item, so the content below gains
/// no gap meanwhile.
struct TileCarousel<Item: Identifiable, SeeAll: Hashable, Tile: View>: View {
    let items: [Item]
    let title: String
    let seeAll: SeeAll
    let seeAllIdentifier: String
    let identifier: String
    var rows = 1
    let tileHeight: CGFloat
    @ViewBuilder let tile: (Item, _ fillsWidth: Bool) -> Tile
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                SectionTitle(text: title) {
                    NavigationLink(value: seeAll) {
                        Text(AppBranding.Groups.seeAll)
                            .font(LilyTheme.Fonts.button)
                            .tappableLabel()
                    }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier(seeAllIdentifier)
                }
                if sizeClass == .regular {
                    grid
                } else {
                    scroll
                }
            }
        }
    }

    private var grid: some View {
        TileGrid(data: items) { item in
            tile(item, true)
        }
        // A container's identifier would otherwise be stamped on every tile and hide theirs.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    private var scroll: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: gridRows, spacing: DesignTokens.Spacing.md) {
                ForEach(items) { item in
                    tile(item, false)
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, DesignTokens.Layout.screenMargin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(identifier)
    }

    private var gridRows: [GridItem] {
        Array(repeating: GridItem(.fixed(tileHeight), spacing: DesignTokens.Spacing.md), count: rows)
    }
}

/// A tile that pushes a value on the stack it is in, found by its identifier; every stack registers the destinations.
struct TileLink<Value: Hashable, Tile: View>: View {
    let value: Value
    let identifier: String
    @ViewBuilder let tile: () -> Tile

    var body: some View {
        NavigationLink(value: value) {
            tile()
        }
        .buttonStyle(.plain)
        .lilyHoverable()
        .accessibilityIdentifier(identifier)
    }
}

/// What every tile shows: the mark, the name on one line and one caption line per entry under it.
struct TileContent: View {
    let avatar: AvatarCircle
    let title: String
    let lines: [String]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            avatar
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                ForEach(Array(lines.enumerated()), id: \.offset) { line in
                    Text(line.element)
                        .font(LilyTheme.Fonts.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

extension View {
    /// The glass surface every carousel tile shares: the carousel's fixed width (so its rows line up), or the whole
    /// cell in a `TileGrid`, at one height.
    func glassTile(fixedWidth: CGFloat, height: CGFloat, fillsWidth: Bool) -> some View {
        padding(.horizontal, DesignTokens.Spacing.md)
            .frame(width: fillsWidth ? nil : fixedWidth, height: height)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .glassEffect(.regular, in: .rect(cornerRadius: DesignTokens.Radius.card))
            .contentShape(.rect)
    }
}
