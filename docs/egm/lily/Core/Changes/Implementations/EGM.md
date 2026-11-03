# Changes Implementations

Source: `lily/Core/Changes/Implementations/`

## Overview

Two `ListSnapshotStore`s. `FileListSnapshotStore` keeps each list's last answer as a JSON file under
`Caches/ListSnapshots/`, guarded by a format marker so snapshots from an older build never show; `NoOpListSnapshotStore`
keeps nothing, for mock runs and lists that are no tab's. Both are main-actor classes; the file store's reads and writes
are synchronous on purpose (a few kilobytes, read once when the list is built and written once per answer).

## Interface

- `FileListSnapshotStore: ListSnapshotStore` (`lily/Core/Changes/Implementations/FileListSnapshotStore.swift:FileListSnapshotStore`):
  `init(directory: URL, logger: any Logging)`; `static var defaultDirectory: URL` (the default lives in `AppDependencies.makeListSnapshotStore`)
  (`Caches/<AppConfig.Lists.snapshotDirectoryName>`); `load(_:for:)`, `save(_:for:)`, `clear()`, `sessionDidEnd()`.
  Coding through `APIJSONCoding.makeDecoder()` and `makeEncoder()` (`lily/Core/Networking`), so a wire type comes back as
  it arrived.
- `NoOpListSnapshotStore: ListSnapshotStore` (`lily/Core/Changes/Implementations/NoOpListSnapshotStore.swift:NoOpListSnapshotStore`):
  `load` returns `nil`; `save`, `clear` and `sessionDidEnd` do nothing.

## Invariants

- Format sweep at init (`FileListSnapshotStore.swift:sweepAnotherFormat`): when the directory exists and its marker file
  (`AppConfig.Lists.snapshotFormatFileName`) does not read `String(AppConfig.Lists.snapshotFormat)`, the whole directory
  is removed. If that removal fails, `holdsAnotherFormat` stays true: `load` answers `nil` and `save` writes nothing
  until a `clear()` succeeds (the next launch sweeps again).
- `load` drops a file that no longer decodes (removes it, warns, answers `nil`), so the next launch is a plain miss; a
  missing file is a debug miss (`FileListSnapshotStore.swift:load`).
- `save` creates the directory and writes the marker when absent (`prepareDirectory`), then writes the file atomically in
  place of whatever was there; any failure is a warning, never thrown (`FileListSnapshotStore.swift:save`).
- `removeDirectory()` logs "cleared" only on success; a refused removal is a warning and resets nothing, so a failed
  clear never claims a clean device. `sessionDidEnd()` calls `clear()` (`FileListSnapshotStore.swift:removeDirectory`).
- Files are named by `ListSnapshotKey.fileName` (`<list>.<caller>.json`) inside `directory` (`FileListSnapshotStore.swift:location(of:)`).

## Side Effects

- Disk: reads, atomic writes and removals under `Caches/ListSnapshots/` through `FileManager.default`,
  `Data.write(to:options: .atomic)` and `FileManager.removeItemIfPresent(at:)` (`lily/Core/System`); the system may purge
  `Caches/`, which reads as a miss (`FileListSnapshotStore.swift`).
- Logging under `.cache` (`FileListSnapshotStore.swift`): debug for hit, miss, held-back read, cleared; info for a format
  sweep; warning for an unreadable snapshot, a failed store, a held-back write, a failed clear.
- `NoOpListSnapshotStore`: none.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Changes`).
