# Localization Models

Source: `lily/Core/Localization/Models/`

## Overview

The seven languages the app ships copy in, and the user's language choice as a stored value (follow the system, or one
language whatever the device speaks). `LanguagePreference` conforms to `StoredChoice`
(`lily/Core/Preferences/Interfaces/StoredChoice.swift`).

## Interface

- `AppLanguage` (`lily/Core/Localization/Models/AppLanguage.swift:AppLanguage`): `nonisolated enum: String, CaseIterable,
  Sendable`; cases `english = "en"`, `russian = "ru"`, `spanish = "es"`, `french = "fr"`, `ukrainian = "uk"`,
  `polish = "pl"`, `portuguese = "pt"`; `static let fallback = .english`; `code: String` (the raw value);
  `nativeName: String` (the language's own name for itself);
  `static systemChoice(preferredLocalizations: [String] = Bundle.main.preferredLocalizations) -> AppLanguage`;
  `init?(localization: String)`.
- `LanguagePreference` (`lily/Core/Localization/Models/LanguagePreference.swift:LanguagePreference`): `nonisolated enum:
  StoredChoice`; `.system`, `.fixed(AppLanguage)`; `static let storageKey = AppConfig.Storage.Keys.languagePreference`,
  `static let logCategory = LogCategory.localization`; `storedValue: String`; `init(storedValue: String?)`;
  `resolved(systemChoice: AppLanguage) -> AppLanguage`; `fixedLanguage: AppLanguage?`.

## Invariants

- `AppLanguage.systemChoice` is the first preferred localization that maps to an `AppLanguage`, else `.english`;
  `init?(localization:)` reduces a tag to its language code and lower-cases it (`pt-BR` and `pt_PT` are Portuguese), so
  a region never selects a different catalog (`AppLanguage.swift:systemChoice`, `init(localization:)`).
- `LanguagePreference.init(storedValue:)` yields `.system` for `nil` or an unknown code; `storedValue` is
  `AppConfig.Storage.systemChoiceValue` for `.system`, else the language code; `fixedLanguage` is `nil` while following
  the system (`LanguagePreference.swift`).

## Side Effects

- `AppLanguage.systemChoice()` reads `Bundle.main.preferredLocalizations` by default. Nothing is written.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Localization`).
