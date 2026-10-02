import Foundation

/// How a bubble lays its pictures and videos out: one fills the gallery at its own aspect ratio; two sit side by side;
/// three or four form a two-column grid of squares, a lone tile in the last row spanning both columns; more than four
/// show the first four with "+N" on the last. Files are never tiles: `partition` keeps them apart as cards under the
/// grid. Pure, so the rules are tested without a view.
nonisolated struct GalleryLayout: Equatable, Sendable {
    static let maxTiles = 4
    static let columns = 2

    /// Which attachments of a message the grid draws (pictures and videos, in their order) and which become cards
    /// under it (files), both as indices into the message's attachments.
    struct Partition: Equatable, Sendable {
        let media: [Int]
        let files: [Int]
    }

    let count: Int

    init(count: Int) {
        self.count = count
    }

    static func partition(_ kinds: [AttachmentKind]) -> Partition {
        let indexed = kinds.enumerated()
        return Partition(media: indexed.filter { $0.element.isMedia }.map(\.offset),
                         files: indexed.filter { !$0.element.isMedia }.map(\.offset))
    }

    var isSingle: Bool { count == 1 }
    /// Tiles drawn.
    var shownCount: Int { min(count, Self.maxTiles) }
    /// Pictures behind the last tile's "+N".
    var hiddenCount: Int { max(count - Self.maxTiles, 0) }

    /// The indices of the tiles drawn, row by row.
    var rows: [[Int]] {
        stride(from: 0, to: shownCount, by: Self.columns).map { start in
            Array(start..<min(start + Self.columns, shownCount))
        }
    }

    /// Whether the tile at `index` takes both columns: the lone tile of a last row in a grid.
    func spansRow(_ index: Int) -> Bool {
        guard !isSingle, let last = rows.last, last.count == 1 else { return false }
        return last[0] == index
    }

    /// Whether the tile at `index` carries the "+N" scrim.
    func showsOverflow(at index: Int) -> Bool {
        hiddenCount > 0 && index == shownCount - 1
    }
}
