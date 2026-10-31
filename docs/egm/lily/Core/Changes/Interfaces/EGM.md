# Changes Interfaces

Source: `lily/Core/Changes/Interfaces/`

## Overview

The one protocol of the snapshot layer: where a list's last answer is kept on the device, so the first frame of the next
launch (or of a tab opened before its load answered) shows it while the fresh answer loads, and the key that names one
list for one caller.

## Interface

- `ListSnapshotKey` (`lily/Core/Changes/Interfaces/ListSnapshotStore.swift:ListSnapshotKey`): `nonisolated struct: Hashable,
  Sendable`; `list: String`, `userID: String?`; `fileName: String` is `"<list>.<userID or AppConfig.Lists.guestSnapshotName>.json"`.
- `ListSnapshotStore` (`lily/Core/Changes/Interfaces/ListSnapshotStore.swift:ListSnapshotStore`): refines `SessionObserver`
  (`lily/Core/Auth/Interfaces/SessionObserver.swift`); `load<Value: Decodable>(_ type: Value.Type, for key: ListSnapshotKey) -> Value?`,
  `save<Value: Encodable>(_ value: Value, for key: ListSnapshotKey)`, `clear()`. Main-actor by the target's default;
  the calls are synchronous.
- Conformers: [Implementations](../Implementations/EGM.md).

## Invariants

- A snapshot is a hint, never the truth: every list still loads on its own rules and replaces it
  (`ListSnapshotStore.swift:ListSnapshotStore`).
- Snapshots are per caller: Mine, the caller's games and Explore's `isJoined` flags are one caller's answer, so the
  `userID` in the key keeps a guest's Explore and each user's lists apart (`ListSnapshotStore.swift:ListSnapshotKey`).
- A conformer is a `SessionObserver`, so it is cleared with the session and one account's lists never show for the next
  (`ListSnapshotStore.swift:ListSnapshotStore`).

## Side Effects

- None in this directory; the file I/O is in [Implementations](../Implementations/EGM.md).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Changes`).
