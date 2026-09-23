import Foundation

/// Body of `POST /api/interactions`.
nonisolated struct InteractionBatch: Encodable, Equatable, Sendable {
    let interactions: [Interaction]
}

/// Its `202` answer: how many the backend took.
nonisolated struct InteractionReceipt: Decodable, Equatable, Sendable {
    let accepted: Int
}
