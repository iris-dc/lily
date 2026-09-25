import Foundation

nonisolated extension String {
    /// Length as the backend measures it: Java's `String.length()`, and so Bean Validation's `@Size`, count UTF-16
    /// units, so an emoji counts two here as it does there and a draft that passes is never refused for its length.
    var wireLength: Int { utf16.count }
}

nonisolated extension String? {
    /// `nil` (a field the user left empty) has no length to refuse.
    var wireLength: Int { self?.wireLength ?? 0 }
}
