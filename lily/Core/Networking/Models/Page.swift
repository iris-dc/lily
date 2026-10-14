import Foundation

/// One page of a cursor-paged list, as the backend answers `{items, nextCursor}`; a list without paging leaves the
/// cursor out, so a plain `{items}` decodes too.
nonisolated struct Page<Item: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    let items: [Item]
    /// Opaque; passed back as the `cursor` query parameter. Absent on the last page.
    let nextCursor: String?

    init(items: [Item], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }
}
