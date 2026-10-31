# Feedback Interfaces

Source: `lily/Features/Feedback/Interfaces/`

## Overview

One protocol, `FeedbackRepository`, is the boundary between the contact form's view model and the transport that
stores a message. `RemoteFeedbackRepository` and `MockFeedbackRepository` ([Implementations](../Implementations/EGM.md))
conform, and `AppDependencies` injects one of them as `feedbackRepository`.

## Interface

- `FeedbackRepository` (`lily/Features/Feedback/Interfaces/FeedbackRepository.swift`):
  `func send(_ feedback: FeedbackPayload) async throws -> FeedbackReceipt`. No inherited protocols, no `Sendable` or
  `AnyObject` constraint, no other requirements.

## Invariants

- The signature carries no idempotency key, kind filter or batching; the doc comment states "One send is one stored
  item; nothing is replayed" (documented on the protocol, enforced by nothing in this directory).
- No `nonisolated` marker: the protocol inherits the app target's default `@MainActor` isolation.

## Side Effects

- None. A protocol declaration only; the POST lives in `lily/Features/Feedback/Implementations/`.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Feedback/RemoteFeedbackRepositoryTests.swift`
  exercises the conformance).
