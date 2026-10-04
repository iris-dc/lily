import Foundation

/// A response type that may arrive without a body (`204 No Content`): the client answers `empty` for empty data
/// instead of asking the JSON decoder to read nothing.
protocol EmptyDecodable: Decodable {
    static var empty: Self { get }
}

/// The answer of a route that says nothing (`DELETE .../entries/{entryId}` is `204`).
nonisolated struct NoContent: EmptyDecodable, Equatable, Sendable {
    static var empty: NoContent { NoContent() }

    init() {}

    /// Anything in the body is ignored: the route promised none.
    init(from decoder: any Decoder) throws {}
}

/// A body that is sometimes there: `value` is the decoded answer, or `nil` for a `204`.
nonisolated struct OptionalBody<Wrapped: Decodable & Sendable>: EmptyDecodable, Sendable {
    let value: Wrapped?

    static var empty: OptionalBody { OptionalBody(value: nil) }

    init(value: Wrapped?) {
        self.value = value
    }

    init(from decoder: any Decoder) throws {
        value = try Wrapped(from: decoder)
    }
}
