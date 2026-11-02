# Networking Implementations

Source: `lily/Core/Networking/Implementations/`

## Overview

The production `APIClient` over `URLSession` and the JSON conventions it shares with the backend. The client knows the
base URL, the two identity headers, the version header and the status-code rules, nothing else; mapping an
`APIError` to an `AppError` happens in `lily/Core/Networking/APIFailureMapping.swift` (`../EGM.md`).

## Interface

- `nonisolated enum APIJSONCoding`: `static func makeDecoder() -> JSONDecoder`,
  `static func makeEncoder() -> JSONEncoder`, `static func parseInstant(_ text: String) -> Date?`
  [`lily/Core/Networking/Implementations/APIJSONCoding.swift:APIJSONCoding`].
- `final class URLSessionAPIClient: APIClient` (main-actor):
  `init(session: URLSession = makeSession(), baseURL: URL = AppConfig.API.baseURL, identity: any IdentityProvider, tokenProvider: (any AuthTokenProvider)? = nil, sendsLocalUserHeader: Bool = AppConfig.API.sendsLocalUserHeader, appVersion: AppVersion = .current(), logger: any Logging)`;
  `static func makeSession() -> URLSession`;
  `func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response`
  [`lily/Core/Networking/Implementations/URLSessionAPIClient.swift:URLSessionAPIClient`].

## Invariants

- Decoder dates: a custom strategy parses ISO-8601 with fractional seconds first, then the plain form; anything else
  throws `DecodingError.dataCorrupted`. Encoder dates: `.iso8601`. Key names are left as they are (no key strategy)
  [`APIJSONCoding.swift:APIJSONCoding.makeDecoder()`, `APIJSONCoding.swift:APIJSONCoding.makeEncoder()`].
- `makeSession()` is `URLSessionConfiguration.default` with `timeoutIntervalForRequest = AppConfig.API.requestTimeout`
  and no delegate [`URLSessionAPIClient.swift:URLSessionAPIClient.makeSession()`].
- Every request carries `Accept: AppConfig.API.Headers.json` and the version header
  (`AppConfig.API.Headers.appVersion` = `AppVersion.headerValue`). A body is JSON-encoded and adds the
  `Content-Type` header. `AppConfig.API.Headers.localUserID` is sent only when `sendsLocalUserHeader` and
  `identity.currentUserID` is set. The `Authorization` header (`bearerPrefix + token`) is sent only when
  `identity.currentUserID != nil` and `tokenProvider?.accessToken()` answers one: gated on the app's session, not on
  the keychain [`URLSessionAPIClient.swift:URLSessionAPIClient.makeURLRequest(_:)`].
- Query items are percent-encoded with `urlQueryAllowed` minus `+&=`, so a `+` in a search reaches the backend as `+`
  [`URLSessionAPIClient.swift:URLSessionAPIClient.queryAllowed`, `URLSessionAPIClient.swift:URLSessionAPIClient.url(_:path:query:)`].
- Status handling: a non-`HTTPURLResponse` throws `APIError.notHTTPResponse`; a status outside `200..<300` throws
  `APIError.http(status:, body: the decoded {code, message} if any, retryAfter: Retry-After in seconds if present)`.
  The failure log is a warning when the status is in `AppConfig.API.clientErrorStatuses` but not
  `AppConfig.API.contentTooLargeStatus` (a 413 `REQUEST_TOO_LARGE` is the app's drift, so it logs at error although its
  code is known) and the body code is a known `BackendErrorCode`, or the status is `AppConfig.API.unauthorizedStatus` or
  `AppConfig.API.rateLimitedStatus`; otherwise an error. The log carries the code, never the body
  [`URLSessionAPIClient.swift:URLSessionAPIClient.failure(_:data:endpoint:)`, `URLSessionAPIClient.swift:URLSessionAPIClient.isRefusal(status:body:)`].
- Decoding: empty data with an `EmptyDecodable` response type answers `.empty`; otherwise the JSON decoder runs and a
  failure throws `APIError.decodingFailed` [`URLSessionAPIClient.swift:URLSessionAPIClient.decode(_:from:endpoint:)`].
- Transport failures (`URLError`) are logged and rethrown unchanged; a cancellation (`AppError.isCancellation`) is
  logged at debug, anything else at warning [`URLSessionAPIClient.swift:URLSessionAPIClient.perform(_:endpoint:)`].
- The token is read per request and never logged; log lines name the endpoint by `logPath` when the request has one
  [`URLSessionAPIClient.swift:URLSessionAPIClient.send(_:)`].

## Side Effects

- `URLSession.data(for:)` once per `send` [`URLSessionAPIClient.swift:URLSessionAPIClient.perform(_:endpoint:)`].
- Reads `identity.currentUserID` and `tokenProvider?.accessToken()` per request
  [`URLSessionAPIClient.swift:URLSessionAPIClient.makeURLRequest(_:)`].
- Logging under `.network`: debug "Sending <METHOD path>" and "<endpoint> cancelled"; warning "<endpoint> failed before
  a response"; warning or error "<endpoint> failed with status <N> (<CODE>)"; error "<endpoint> returned a non-HTTP
  response" and "<endpoint> returned a body that does not decode as <Type>"
  [`URLSessionAPIClient.swift:URLSessionAPIClient`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Networking`)
