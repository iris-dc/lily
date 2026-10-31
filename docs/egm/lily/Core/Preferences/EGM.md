# Preferences

Source: `lily/Core/Preferences/`

## Overview

How a Profile choice (the app language, the currency) survives a relaunch: one string per choice in `UserDefaults`,
either `AppConfig.Storage.systemChoiceValue` to follow the system or the choice's code. The directory holds no source
files of its own: the seam is in `Interfaces/` and the single `UserDefaults` store in `Implementations/`. A value this
build cannot read (a language it does not ship, a currency no longer offered) reads as the system choice and is logged
as a warning naming the key, never the value.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `ChoiceStore<Choice>` (`load`, `save`, `clear`) and the
  `StoredChoice` protocol a choice conforms to (`storageKey`, `logCategory`, `init(storedValue:)`, `storedValue`).
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `UserDefaultsChoiceStore<Choice>`, the
  generic `UserDefaults` store that reads, writes and removes under `Choice.storageKey`.
