import Foundation

/// The display name as typed and its validation against `AppConfig.DisplayName`.
nonisolated struct DisplayNameDraft: ProfileFieldDraft {
    var text: String

    init(text: String = "") {
        self.text = text
    }

    var trimmedText: String { text.trimmed }

    /// Empty when the draft may go out; a blank name is missing before it is anything else.
    var issues: [Issue] {
        if trimmedText.isEmpty { return [.nameMissing] }
        if trimmedText.codePointCount > AppConfig.DisplayName.length.upperBound { return [.nameTooLong] }
        return []
    }

    var isValid: Bool { issues.isEmpty }

    /// A missing name only keeps Save disabled, since the empty field explains itself.
    var hint: String? {
        issues.contains(.nameTooLong) ? AppBranding.DisplayName.tooLong(limit: AppConfig.DisplayName.length.upperBound) : nil
    }

    nonisolated enum Issue: Equatable, Sendable {
        case nameMissing, nameTooLong
    }
}
