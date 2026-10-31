# Preferences Implementations

Source: `lily/Core/Preferences/Implementations/`

## Overview

The `UserDefaults`-backed `ChoiceStore` (`../Interfaces/EGM.md`). Generic over the `StoredChoice` it keeps, so the
language and currency pickers share one implementation and differ only in their key and log category.

## Interface

- `final class UserDefaultsChoiceStore<Choice: StoredChoice>: ChoiceStore` (main-actor):
  `init(defaults: UserDefaults = .standard, logger: any Logging)`; `load() -> Choice`; `save(_:)`; `clear()`
  [`lily/Core/Preferences/Implementations/UserDefaultsChoiceStore.swift:UserDefaultsChoiceStore`].

## Invariants

- `load()` reads `defaults.string(forKey: Choice.storageKey)` and builds `Choice(storedValue: raw)`; when a value was
  stored but `raw != choice.storedValue` (this build could not read it), a warning names the key, never the value, and
  the system choice is returned [`UserDefaultsChoiceStore.swift:UserDefaultsChoiceStore.load()`].
- `save` writes `choice.storedValue`; `clear` removes the key
  [`UserDefaultsChoiceStore.swift:UserDefaultsChoiceStore.save(_:)`, `UserDefaultsChoiceStore.swift:UserDefaultsChoiceStore.clear()`].

## Side Effects

- `UserDefaults` read, write and remove under `Choice.storageKey` [`UserDefaultsChoiceStore.swift:UserDefaultsChoiceStore`].
- Logging under `Choice.logCategory` at warning: "Stored value under <key> could not be read; following the system"
  [`UserDefaultsChoiceStore.swift:UserDefaultsChoiceStore.load()`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Preferences`)
