import Foundation

nonisolated extension String {
    /// The text without surrounding whitespace and newlines, how every typed field is read.
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// `trimmed`, or `nil` when nothing but whitespace was written: what an optional payload field omits.
    var nonBlankTrimmed: String? {
        let text = trimmed
        return text.isEmpty ? nil : text
    }
}

nonisolated extension String? {
    var trimmed: String { self?.trimmed ?? "" }

    var nonBlankTrimmed: String? { self?.nonBlankTrimmed }
}
