# Concurrency

Source: `lily/Core/Concurrency/`

## Overview

Six small helpers that give the app's async code its cancellation and ordering rules: a deadline whose loser is
cancelled but not awaited (`Deadline`), a head start whose loser is left to finish (`HeadStart`), one run at a time keyed
by caller (`SingleFlight`), at most N at a time in order (`SlotGate`), off-main-actor work that dies with its caller
(`DetachedWork`), and the injectable pause tests hold instead of waiting on a clock (`Sleep`, `systemSleep`).

## Interface

- `Sleep` (`lily/Core/Concurrency/Sleep.swift:Sleep`): `typealias Sleep = @Sendable (Duration) async throws -> Void`;
  `nonisolated let systemSleep: Sleep` wraps `Task.sleep(for:)`.
- `Deadline` (`lily/Core/Concurrency/Deadline.swift:Deadline`): `enum` with `nonisolated struct Expired: Error`;
  `static within(_ timeout: Duration, sleep: @escaping Sleep = systemSleep, orThrow expired: any Error = Expired(), _ work: @escaping () async throws -> Void) async throws`.
- `HeadStart` (`lily/Core/Concurrency/HeadStart.swift:HeadStart`):
  `static give(_ timeout: Duration, sleep: @escaping Sleep = systemSleep, to work: @escaping () async -> Void, then: @escaping () async -> Void) async`.
- `SingleFlight` (`lily/Core/Concurrency/SingleFlight.swift:SingleFlight`): `@Observable final class`; `isRunning: Bool`;
  `run(key: AnyHashable? = nil, _ work: @escaping () async -> Void) async`.
- `SlotGate` (`lily/Core/Concurrency/SlotGate.swift:SlotGate`): `final class`; `init(limit: Int)`;
  `private(set) var active: Int`, `waiting: Int`; `acquire() async throws`, `release()`.
- `DetachedWork` (`lily/Core/Concurrency/DetachedWork.swift:DetachedWork`): `nonisolated enum`;
  `static run<T: Sendable>(priority: TaskPriority = .userInitiated, _ work: @escaping @Sendable @concurrent () async throws -> T) async throws -> T`.

## Invariants

- `Deadline.within`: the first outcome wins (`Deadline.swift:FirstOutcome.settle` ignores a second result); when the
  timer wins it throws `expired` and cancels the worker without awaiting it, so a request that ignores cancellation (a
  stalled socket) cannot hold a sign-out; when the worker finishes first the timer is cancelled. Not for races whose
  loser must finish.
- `HeadStart.give`: `then` runs once `work` returned or `timeout` passed, whichever is first; only the timer is cancelled
  (`group.cancelAll()` after `work` wins), a `work` still running goes on to its end. When the calling task is cancelled
  `then` does not run (`Task.isCancelled` guard): the timer's early return is not the time being up (`HeadStart.swift:give`).
- `SingleFlight.run`: a call with the same key, or with no key, joins the run in flight and returns when it ends; a
  call for another key waits it out and then starts its own (the loop re-reads `task` because another waiter may have
  started a run meanwhile). The work runs in its own `Task`, so a cancelled caller does not take the request down;
  `task` and `runningKey` reset in a `defer` when the work ends (`SingleFlight.swift:run`).
- `SlotGate.acquire`: checks cancellation first; takes a slot when `active < limit`, else parks a `CheckedContinuation`
  in FIFO order. A waiter cancelled before a slot came is removed and thrown `CancellationError` (`cancelWaiter`); one
  that already received the slot returns holding it. `release()` hands the slot to the next waiter (the count stays) or
  decrements `active`. Every return from `acquire` pairs with one `release()` (`SlotGate.swift:acquire`, `release`).
- `DetachedWork.run`: throws before starting for an already-cancelled caller (`Task.checkCancellation`); the detached
  task is cancelled when the awaiting task is (`withTaskCancellationHandler`); `@concurrent` keeps a closure formed on the
  main actor from being inferred as isolated to it (`DetachedWork.swift:run`).

## Side Effects

- Spawned tasks: `Deadline.within` (worker, timer and a settling task); `SingleFlight.run` (one `Task` per run);
  `DetachedWork.run` (`Task.detached` at `priority`); `SlotGate.cancelWaiter` (a `Task { @MainActor }` from the
  cancellation handler); `HeadStart.give` (a two-task group).
- Sleeps: the injected `Sleep` (`systemSleep` in production) for the deadline and head-start timers.
- Observable state: `SingleFlight.isRunning`. No I/O, no logging.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Concurrency`).
