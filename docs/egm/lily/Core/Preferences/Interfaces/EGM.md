# Preferences Interfaces

Source: `lily/Core/Preferences/Interfaces/`

## Overview

The seam for a Profile choice that survives a relaunch (the app language, the currency): what a choice must provide to
be stored as one string, and the store that keeps it. `UserDefaultsChoiceStore` (`../Implementations/EGM.md`) is the
conformer.

## Interface

- `protocol ChoiceStore<Choice>` (main-actor under the app target's default): `associatedtype Choice: StoredChoice`;
  `func load() -> Choice`; `func save(_ choice: Choice)`; `func clear()`
  [`lily/Core/Preferences/Interfaces/ChoiceStore.swift:ChoiceStore`].
- `nonisolated protocol StoredChoice: Hashable, Sendable`: `static var storageKey: String`,
  `static var logCategory: LogCategory`, `init(storedValue: String?)`, `var storedValue: String`
  [`lily/Core/Preferences/Interfaces/StoredChoice.swift:StoredChoice`].

## Invariants

- Documented contract of `StoredChoice`: the value is one string, either `AppConfig.Storage.systemChoiceValue` (follow
  the system) or the choice's code; `init(storedValue:)` must read `nil` and any value this build cannot read as the
  system choice [`lily/Core/Preferences/Interfaces/StoredChoice.swift:StoredChoice.init(storedValue:)`].

## Side Effects

- None (protocol declarations only).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Preferences`)
