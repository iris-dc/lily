# Networking Interfaces

Source: `lily/Core/Networking/Interfaces/`

## Overview

The one transport seam to the backend. Repositories depend on `APIClient` alone; `URLSessionAPIClient`
(`../Implementations/EGM.md`) is its production conformer and `FakeAPIClient` (`lilyTests/Support`) stands in for
tests. The error-mapping convenience `send(_:failingWith:)` is an extension on this protocol declared in
`lily/Core/Networking/APIFailureMapping.swift` (see `../EGM.md`).

## Interface

- `protocol APIClient` (main-actor under the app's default isolation):
  `func send<Response: Decodable>(_ request: APIRequest<Response>) async throws -> Response`
  [`lily/Core/Networking/Interfaces/APIClient.swift:APIClient`].

## Invariants

- Documented contract: `send` throws `APIError` for HTTP and decoding failures and lets transport failures
  (`URLError`) through unchanged, so callers can still tell a cancelled request from a failed one
  [`lily/Core/Networking/Interfaces/APIClient.swift:APIClient.send(_:)`].
- Implementations build the URL, attach identity, and encode and decode JSON; the protocol itself carries no base URL,
  headers or coding rules [`lily/Core/Networking/Interfaces/APIClient.swift:APIClient`].

## Side Effects

- None (protocol declaration only).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Networking`)
