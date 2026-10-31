# Inbox Interfaces

Source: `lily/Features/Inbox/Interfaces/`

## Overview

The boundary between the inbox feature and whatever serves it: one protocol, `InboxRepository`, naming the four
operations the inbox needs (a page of items, the read marker, accepting and declining an invite). `InboxStore` and
`InboxViewModel` depend on this protocol only; the concrete remote and mock types live in `../Implementations/`.

## Interface

- `protocol InboxRepository` `[lily/Features/Inbox/Interfaces/InboxRepository.swift:InboxRepository]`: not
  `nonisolated`, so main-actor isolated under the app target's default isolation; four `async throws` requirements:
  - `func page(before itemID: String?, limit: Int) async throws -> InboxPage`: the newest `limit` items when
    `before` is `nil`, otherwise the `limit` items before that id.
  - `func markRead(itemID: String) async throws -> String`: answers where the read marker now stands.
  - `func accept(itemID: String) async throws -> InviteAcceptance`.
  - `func decline(itemID: String) async throws -> InboxItem`.
- The types named here are in [Models](../Models/EGM.md); the implementations in
  [Implementations](../Implementations/EGM.md).

## Invariants

- The protocol carries no executable guards; its doc comments state the contract every implementation keeps
  `[lily/Features/Inbox/Interfaces/InboxRepository.swift:InboxRepository]`: every page is ascending by id; failures
  surface as `AppError`; `markRead` is monotonic (an older id leaves the marker where it is, and the returned id is
  the marker's real position); a repeated `accept` of an accepted invite and a repeated `decline` of a declined one
  answer the same shape (idempotent replay).

## Side Effects

- None: a protocol declaration only.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; `lilyTests/Inbox` exercises both implementations through
  this protocol).
