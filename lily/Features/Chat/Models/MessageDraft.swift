import Foundation

/// What the composer holds. The id is chosen once per composed message and sent with every attempt, so a retry after
/// a lost answer replays the stored message instead of posting it twice. Length is UTF-16 units, as the backend counts.
nonisolated struct MessageDraft: Equatable, Sendable {
    /// Lower-case, as the backend stores it.
    let clientMessageID: String
    var text = ""

    init(clientMessageID: String = UUID().uuidString.lowercased()) {
        self.clientMessageID = clientMessageID
    }

    enum Issue: Hashable, Sendable {
        case empty
        case tooLong
    }

    var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var issues: [Issue] {
        var issues: [Issue] = []
        if trimmedText.isEmpty { issues.append(.empty) }
        if trimmedText.wireLength > AppConfig.Chat.messageMaxLength { issues.append(.tooLong) }
        return issues
    }

    var isValid: Bool { issues.isEmpty }

    /// Characters the backend still accepts; negative once the draft is too long.
    var remaining: Int { AppConfig.Chat.messageMaxLength - text.wireLength }

    var payload: SendMessagePayload {
        SendMessagePayload(clientMessageId: clientMessageID, text: trimmedText)
    }
}
