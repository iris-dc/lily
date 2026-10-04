import Foundation

/// A kind the backend sends as one string (`"event_created"`, `"direct"`), with a case that keeps any name this build
/// does not know, so a page or a stream from a newer backend still decodes and the row or group can be hidden or
/// shown plainly instead of failing the whole payload. Conformers name their cases in `init(wireName:)` and
/// `wireName`; the string form on the wire is the same one for every kind.
nonisolated protocol WireNamedKind: Hashable, Codable, Sendable {
    init(wireName: String)
    var wireName: String { get }
}

nonisolated extension WireNamedKind {
    init(from decoder: any Decoder) throws {
        self.init(wireName: try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireName)
    }
}
