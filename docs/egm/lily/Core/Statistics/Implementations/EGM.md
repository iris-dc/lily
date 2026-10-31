# Statistics Implementations

Source: `lily/Core/Statistics/Implementations/`

## Overview

The two `InteractionRecorder` conformers. `RemoteInteractionRecorder` buffers interactions for the signed-in user and
posts them to Laurel in batches; `NoOpInteractionRecorder` keeps and sends nothing for mock runs, previews and UI
tests. Both also conform to `SessionObserver` so a sign-out flushes or drops the buffer. Both are main-actor under the
app target's default isolation.

## Interface

- `final class RemoteInteractionRecorder: InteractionRecorder, SessionObserver`:
  `init(client: any APIClient, identity: any IdentityProvider, logger: any Logging, batchSize: Int = AppConfig.Statistics.batchSize, flushDelay: Duration = AppConfig.Statistics.flushDelay, maxBuffered: Int = AppConfig.Statistics.maxBuffered, signOutTimeout: Duration = AppConfig.Statistics.signOutFlushTimeout, sleep: @escaping Sleep = systemSleep)`;
  `record(_:)`, `flush() async`, `sessionWillEnd() async`, `sessionDidEnd()`
  [`lily/Core/Statistics/Implementations/RemoteInteractionRecorder.swift:RemoteInteractionRecorder`].
- `final class NoOpInteractionRecorder: InteractionRecorder, SessionObserver`: every method is a no-op
  [`lily/Core/Statistics/Implementations/NoOpInteractionRecorder.swift:NoOpInteractionRecorder`].

## Invariants

- A guest (`identity.currentUserID == nil`) is never recorded [`RemoteInteractionRecorder.swift:RemoteInteractionRecorder.record(_:)`].
- Every buffered entry remembers the `userID` it was recorded for; `flush()` sends only the entries whose user is the
  current one and drops the rest, so a sign-out between recording and sending never charges the next user
  [`RemoteInteractionRecorder.swift:RemoteInteractionRecorder.flush()`].
- The buffer is capped at `maxBuffered`; the oldest entries beyond it are dropped on record
  [`RemoteInteractionRecorder.swift:RemoteInteractionRecorder.dropOldestBeyondCapacity()`].
- A send is triggered when `buffer.count >= batchSize` (a `Task` runs `flush()`), else by a single timer armed
  `flushDelay` after the first buffered entry; `flush()` cancels the timer first, and the timer clears its own slot
  before flushing so the flush does not cancel itself. The timer holds `self` weakly
  [`RemoteInteractionRecorder.swift:RemoteInteractionRecorder.record(_:)`, `RemoteInteractionRecorder.swift:RemoteInteractionRecorder.armTimer()`].
- `sessionWillEnd()` flushes within `Deadline.within(signOutTimeout, sleep:)` while the Bearer still goes out; giving
  up is a warning. `sessionDidEnd()` cancels the timer and drops what is still buffered
  [`RemoteInteractionRecorder.swift:RemoteInteractionRecorder.sessionWillEnd()`, `RemoteInteractionRecorder.swift:RemoteInteractionRecorder.sessionDidEnd()`].
- A failed send is a warning and is never retried [`RemoteInteractionRecorder.swift:RemoteInteractionRecorder.send(_:)`].

## Side Effects

- `POST AppConfig.API.Paths.interactions` with an `InteractionBatch`, through `client.send(_, failingWith: .unknown)`
  [`RemoteInteractionRecorder.swift:RemoteInteractionRecorder.send(_:)`].
- Tasks: the flush timer and the batch-size flush `Task`; sleeps through the injected `Sleep`
  [`RemoteInteractionRecorder.swift:RemoteInteractionRecorder.armTimer()`].
- Logging under `.statistics`: debug "Guest <kind> not recorded", "Recorded <kind>; buffered: <N>", "Dropped <N>
  interactions of another user", "Dropped <N> interactions at sign-out", "Buffer full; dropped the oldest <N>"; info
  "Sent <N> interactions; accepted <M>"; warning "Sending <N> interactions failed", "Flush before sign-out gave up"
  [`RemoteInteractionRecorder.swift:RemoteInteractionRecorder`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Statistics`)
