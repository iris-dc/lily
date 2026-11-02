# Networking Models

Source: `lily/Core/Networking/Models/`

## Overview

The value types a backend call is made of: the request description, the error shapes, the version header value, the
empty-body and paged response wrappers, the tolerant string-kind protocol, and the query items a position becomes.
Every type is `nonisolated` and `Sendable` (the `EmptyDecodable` protocol carries no isolation attribute). Nothing here
performs network I/O.

## Interface

- `nonisolated enum HTTPMethod: String, Sendable`: `.get` (`GET`), `.post` (`POST`), `.put` (`PUT`), `.delete`
  (`DELETE`) [`lily/Core/Networking/Models/APIRequest.swift:HTTPMethod`].
- `nonisolated struct APIRequest<Response: Decodable>: Sendable`: `let method: HTTPMethod`, `let path: String`
  (absolute path under `AppConfig.API.baseURL`), `var queryItems: [URLQueryItem] = []`,
  `var body: (any Encodable & Sendable)?`, `var logPath: String?` (the path as the log shows it); factories
  `static func get(_ path:, query: = [])`, `post(_ path:, body: = nil)`, `put(_ path:, body: = nil)`,
  `delete(_ path:, logPath: = nil)` [`lily/Core/Networking/Models/APIRequest.swift:APIRequest`].
- `nonisolated struct APIErrorBody: Decodable, Equatable, Sendable`: `let code: String`, `let message: String`
  [`lily/Core/Networking/Models/APIError.swift:APIErrorBody`].
- `nonisolated enum APIError: Error, Equatable, Sendable`: `.http(status: Int, body: APIErrorBody?, retryAfter: TimeInterval? = nil)`,
  `.notHTTPResponse`, `.decodingFailed` [`lily/Core/Networking/Models/APIError.swift:APIError`].
- `nonisolated struct AppVersion: Equatable, Sendable`: `let marketing: String`, `let build: String`;
  `init(marketing:build:)`, `init(infoDictionary: [String: Any])`, `var headerValue: String`,
  `static func current(bundle: Bundle = .main) -> AppVersion` [`lily/Core/Networking/Models/AppVersion.swift:AppVersion`].
- `nonisolated extension Coordinate { var queryItems: [URLQueryItem] }`
  [`lily/Core/Networking/Models/Coordinate+QueryItems.swift:Coordinate.queryItems`].
- `protocol EmptyDecodable: Decodable { static var empty: Self { get } }`;
  `nonisolated struct NoContent: EmptyDecodable, Equatable, Sendable`;
  `nonisolated struct OptionalBody<Wrapped: Decodable & Sendable>: EmptyDecodable, Sendable { let value: Wrapped? }`
  [`lily/Core/Networking/Models/EmptyBody.swift:EmptyDecodable`, `NoContent`, `OptionalBody`].
- `nonisolated struct Page<Item: Codable & Hashable & Sendable>: Codable, Hashable, Sendable`: `let items: [Item]`,
  `let nextCursor: String?`; `init(items:nextCursor: = nil)` [`lily/Core/Networking/Models/Page.swift:Page`].
- `nonisolated protocol WireNamedKind: Hashable, Codable, Sendable { static var known: [Self]; static func unknown(_
  name: String) -> Self; init(wireName: String); var wireName: String }` with default `init(wireName:)`, `isUnknown`,
  `init(from:)` and `encode(to:)` [`lily/Core/Networking/Models/WireNamedKind.swift:WireNamedKind`].

## Invariants

- `AppVersion.init(infoDictionary:)` reads `AppConfig.Version.marketingKey` and `AppConfig.Version.buildKey`; a missing
  component becomes `AppConfig.Version.unknownComponent`. `headerValue` is `"<marketing> (<build>)"`
  [`AppVersion.swift:AppVersion.init(infoDictionary:)`, `AppVersion.swift:AppVersion.headerValue`].
- `Coordinate.queryItems` uses the `coarse` position, prints each component with
  `String(format: "%.<AppConfig.Events.positionPrecision>f")` (so the separator is always `.`), under the names
  `AppConfig.API.Query.latitude` and `AppConfig.API.Query.longitude`
  [`Coordinate+QueryItems.swift:Coordinate.queryItems`].
- `NoContent.init(from:)` ignores whatever is in the body; `OptionalBody.init(from:)` decodes `Wrapped` from the same
  decoder (not nested under a key); both answer `empty` for an empty body through the client
  [`EmptyBody.swift:NoContent.init(from:)`, `EmptyBody.swift:OptionalBody.init(from:)`].
- `Page.nextCursor` is optional: absent on the last page, and a plain `{items}` decodes
  [`Page.swift:Page`].
- `WireNamedKind` requires `static var known: [Self]`, `static func unknown(_ name: String) -> Self` (a `case
  unknown(String)` satisfies it) and `wireName`; the extension's default `init(wireName:)` answers the first of
  `known` with that name, else `unknown(name)`, and `isUnknown` is `self == Self.unknown(wireName)`, so a kept name
  never passes for the case it spells. It encodes and decodes as one string through a single-value container, so a
  conformer's `unknown` case keeps any name this build does not know instead of failing the payload
  [`WireNamedKind.swift:WireNamedKind.init(wireName:)`, `WireNamedKind.swift:WireNamedKind.isUnknown`,
  `WireNamedKind.swift:WireNamedKind.init(from:)`, `WireNamedKind.swift:WireNamedKind.encode(to:)`].
- `APIError.http.retryAfter` is the `Retry-After` header in seconds when the response carried one
  [`APIError.swift:APIError.http`].

## Side Effects

- `AppVersion.current(bundle:)` reads `bundle.infoDictionary` [`AppVersion.swift:AppVersion.current(bundle:)`].
- Otherwise none (pure values).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Networking`)
