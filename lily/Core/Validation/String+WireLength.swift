import Foundation

nonisolated extension String {
    /// Length as the backend measures it: Java's `String.length()`, and so Bean Validation's `@Size`, count UTF-16
    /// units, so an emoji counts two here as it does there and a draft that passes is never refused for its length.
    var wireLength: Int { utf16.count }

    /// The longest prefix of whole characters within `maxLength` UTF-16 units: a cap the backend enforces by
    /// `String.length()` neither splits an emoji nor lets one through over the limit.
    func prefix(wireLength maxLength: Int) -> String {
        var used = 0
        return String(prefix { character in
            used += character.utf16.count
            return used <= maxLength
        })
    }
}

nonisolated extension String? {
    /// `nil` (a field the user left empty) has no length to refuse.
    var wireLength: Int { self?.wireLength ?? 0 }
}
