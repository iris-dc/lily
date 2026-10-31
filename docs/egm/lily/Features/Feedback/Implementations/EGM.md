# Feedback Implementations

Source: `lily/Features/Feedback/Implementations/`

## Overview

The two `FeedbackRepository` conformers ([Interfaces](../Interfaces/EGM.md)). `RemoteFeedbackRepository` posts the
payload to `AppConfig.API.Paths.feedback` through the `APIClient` failure-mapping extension with `.feedbackFailed` as
the fallback error. `MockFeedbackRepository` accepts every payload, keeps it in an in-memory array, logs under
`.feedback` and fabricates a receipt from a UUID and an injectable clock. `AppDependencies` wires the remote one for
live runs and the mock one for mock runs. Neither class is `nonisolated` or `Sendable`; both run on the main actor by
the target's default.

## Interface

- `RemoteFeedbackRepository` (`lily/Features/Feedback/Implementations/RemoteFeedbackRepository.swift`):
  `final class`, `init(client: any APIClient)`, `func send(_ feedback: FeedbackPayload) async throws ->
  FeedbackReceipt`.
- `MockFeedbackRepository` (`lily/Features/Feedback/Implementations/MockFeedbackRepository.swift`): `final class`,
  `private(set) var sent: [FeedbackPayload]`, `init(logger: any Logging, now: @escaping () -> Date = { .now })`,
  `func send(_ feedback: FeedbackPayload) async throws -> FeedbackReceipt`.

## Invariants

- `RemoteFeedbackRepository.send` is one call, one POST: no retry, no idempotency key, no local cache. Failures map
  through `APIClient.send(_:failingWith:)` (`lily/Core/Networking/APIFailureMapping.swift`): a backend `APIError`
  becomes its coded `AppError` or the fallback `.feedbackFailed`, a `URLError` other than `.cancelled` becomes
  `.network`, cancellation passes through.
- `MockFeedbackRepository.send` never throws: it appends the payload to `sent` and answers
  `FeedbackReceipt(id: UUID().uuidString.lowercased(), createdAt: now())`.
- `sent` is mutable instance state inspected by tests; the mock is main-actor isolated like the remote.

## Side Effects

- Network (`RemoteFeedbackRepository.send`): `POST /api/feedback` (`AppConfig.API.Paths.feedback`,
  `lily/Config/AppConfig+Feedback.swift`) built with `APIRequest<FeedbackReceipt>.post(_:body:)`, which JSON-encodes
  the `FeedbackPayload`; the answer decodes as `FeedbackReceipt`.
- In-memory state (`MockFeedbackRepository.send`): appends to `sent` for the process lifetime.
- Logging (`MockFeedbackRepository.send`): `logger.info(.feedback, "Mock feedback accepted (<kind>)")`.
- Clock and randomness (`MockFeedbackRepository.send`): `UUID()` and the injected `now()`.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Feedback/RemoteFeedbackRepositoryTests.swift`).
