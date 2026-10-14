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
    /// `""` for `nil`, else the text trimmed.
    var trimmed: String { self?.trimmed ?? "" }

    /// `nil` for `nil` or blank text, else the trimmed text.
    var nonBlankTrimmed: String? { self?.nonBlankTrimmed }
}
