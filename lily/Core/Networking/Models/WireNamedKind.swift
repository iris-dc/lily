import Foundation

/// A kind the backend sends as one string (`"event_created"`, `"direct"`), with a case that keeps any name this build
/// does not know, so a page or a stream from a newer backend still decodes and the row or group can be hidden or
/// shown plainly instead of failing the whole payload. A conformer declares its cases, `known` and `wireName`; the
/// lookup, `isUnknown` and the single-string `Codable` come from the extension, so every kind reads the wire the
/// same way.
nonisolated protocol WireNamedKind: Hashable, Codable, Sendable {
    /// The cases this build names, in the order a chip or picker offers them; a name a newer backend sends is never
    /// among them.
    static var known: [Self] { get }
    /// The case that keeps a name this build does not know; `case unknown(String)` satisfies it.
    static func unknown(_ name: String) -> Self
    init(wireName: String)
    var wireName: String { get }
}

nonisolated extension WireNamedKind {
    init(wireName: String) {
        self = Self.known.first { $0.wireName == wireName } ?? Self.unknown(wireName)
    }

    var isUnknown: Bool { self == Self.unknown(wireName) }

    init(from decoder: any Decoder) throws {
        self.init(wireName: try decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wireName)
    }
}
