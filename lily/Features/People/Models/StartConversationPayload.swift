import Foundation

/// Body of `POST /api/conversations`: the person to open (or answer again) the direct conversation with.
nonisolated struct StartConversationPayload: Encodable, Equatable, Sendable {
    let userId: String
}
