import Foundation

/// The display name as typed and its validation against `AppConfig.DisplayName`, measured in code points as Laurel
/// measures it, so a name that passes here is stored as typed, never cut.
nonisolated struct DisplayNameDraft: Equatable, Sendable {
    var name: String

    init(name: String = "") {
        self.name = name
    }

    var trimmedName: String { name.trimmed }

    /// Empty when the draft may go out; a blank name is missing before it is anything else.
    var issues: [Issue] {
        if trimmedName.isEmpty { return [.nameMissing] }
        if trimmedName.codePointCount > AppConfig.DisplayName.length.upperBound { return [.nameTooLong] }
        return []
    }

    var isValid: Bool { issues.isEmpty }

    /// The line under the field, if any; a missing name only keeps Save disabled, since the empty field explains itself.
    var hint: String? {
        issues.contains(.nameTooLong) ? AppBranding.DisplayName.tooLong(limit: AppConfig.DisplayName.length.upperBound) : nil
    }

    nonisolated enum Issue: Equatable, Sendable {
        case nameMissing, nameTooLong
    }
}
