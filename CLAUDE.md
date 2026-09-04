# Lily — Project Guide

Lily is a meetup-style iOS app for sport events. Users sign in, create events, join events, and chat with the other participants of an event. The backend runs on AWS on a tight budget.

## Product Scope

- **Auth**: sign up, log in, log out, session persistence.
- **Events**: create, browse, join, leave. An event has a sport type, a required number of participants, a time, and a location.
- **Chat**: one chat room per event, visible only to participants.
- **Design**: modern and minimalistic. Reusable SwiftUI components, consistent spacing and typography, no visual clutter.

## Architecture Principles

- **Small services behind interfaces**. Every piece of business logic lives in a small, single-purpose service. Callers depend on a protocol/interface, never on the concrete type. This keeps code testable and swappable.
- **Interfaces and implementations live apart**. Protocols/interfaces go in their own folder; concrete types go in an `Implementations/` folder. Never mix the two in one place.
- **Small, meaningful functions**. One responsibility per function. If a function or class grows, split it and move the parts to the right folder.
- **No duplication**. Before writing code, look for something that already does it. Extract shared logic into reusable components, helpers, or extensions.
- **Constants and configuration in dedicated files**. No magic strings or numbers inline. Keep them in `Config/AppConfig.swift` (and related files under `Config/`), grouped by domain (API endpoints, cache TTLs, UI spacing, feature limits).
- **Well-organized folders**. Group by feature and by layer (for example `Features/Events/Views`, `Features/Events/Services`, `Core/Networking`, `Core/UI/Components`).

## Cost Discipline (AWS)

- **Cache locally first**. Read from an on-device cache and only hit the network when data is stale or missing. Never poll DynamoDB or other services in a loop.
- **Prefer serverless and pay-per-use**: Lambda, DynamoDB on-demand, API Gateway, Cognito. Avoid always-on compute unless there is a proven need.
- **Batch and debounce** network calls where possible.
- **Question every new AWS resource** on cost before adding it.

## Distributed-Systems Correctness

The backend may run on multiple hosts at once. Every design must hold under that assumption:

- No in-memory state that must be shared across requests. Shared state lives in DynamoDB or another shared store.
- Writes that can race (joining an event when seats are limited) use conditional writes or atomic counters.
- Handlers are idempotent where a client might retry.
- Local caches are treated as hints, never as the source of truth.

## Error Handling

- The iOS app surfaces every user-facing error through the **existing shared error popup component**. Do not create new alert styles per screen.
- Errors are typed and mapped to user-friendly messages in one place.
- Failures are logged with enough context to reproduce them.

## Logging

Log the key events that a future debugging session would need:

- Auth: login success/failure, logout, token refresh.
- Events: create, join, leave, capacity reached.
- Chat: connection open/close, send failure.
- Network: request failures with status code and endpoint.
- Cache: hit, miss, invalidation.

Use a single logging facade (behind an interface) so the sink can change without touching call sites. Never log secrets or PII.

## Testing

- All business logic is covered by unit tests. Services depend on interfaces so they can be tested with fakes.
- The project must be runnable and testable locally without AWS credentials (use local fakes or mocks for AWS-backed services).
- Verify there are no memory leaks (retain cycles, unreleased observers) or connection leaks (unclosed sockets, streams, or clients).

## Workflow: Before Every Commit

1. **Spawn a review agent** to deeply review all uncommitted changes.
2. The agent must check and, where needed, fix:
   - Simplicity and readability. Small functions, clear names.
   - No redundancy. Shared logic is extracted and reused.
   - Interfaces and implementations are in separate folders.
   - Constants and config are in dedicated config files.
   - Logic is covered by tests and tests pass.
   - No memory or connection leaks.
   - Distributed-systems safety (see section above).
   - Errors reach the user via the shared popup.
   - Key events are logged.
   - Everything runs and tests locally.
   - `README.md` reflects the current state of the project.
3. Refactor and re-run tests until the review passes.
4. Only then commit.

## Documentation

- Keep `README.md` current: setup, how to run locally, how to run tests, folder layout, AWS deployment steps.
- Document architectural decisions briefly when they are non-obvious.
