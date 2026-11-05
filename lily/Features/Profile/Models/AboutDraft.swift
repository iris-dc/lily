import Foundation

/// The "About you" text as typed and its validation against `AppConfig.About`: optional, so a blank is valid and clears
/// the bio; only the cap can stop it.
nonisolated struct AboutDraft: ProfileFieldDraft {
    var text: String

    init(text: String = "") {
        self.text = text
    }

    var trimmedText: String { text.trimmed }

    var issues: [Issue] {
        trimmedText.codePointCount > AppConfig.About.maxLength ? [.tooLong] : []
    }

    var isValid: Bool { issues.isEmpty }

    var hint: String? {
        issues.contains(.tooLong) ? AppBranding.About.tooLong(limit: AppConfig.About.maxLength) : nil
    }

    nonisolated enum Issue: Equatable, Sendable {
        case tooLong
    }
}
