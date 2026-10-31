# Currency Models

Source: `lily/Core/Currency/Models/`

## Overview

The user's currency choice as a stored value: follow the device's region, or one ISO 4217 code whatever the region says.
It conforms to `StoredChoice` (`lily/Core/Preferences/Interfaces/StoredChoice.swift`), the Profile-choice protocol kept in
`UserDefaults` as one string.

## Interface

- `CurrencyPreference` (`lily/Core/Currency/Models/CurrencyPreference.swift:CurrencyPreference`): `nonisolated enum:
  StoredChoice` (hence `Hashable, Sendable`); cases `.system`, `.fixed(String)`;
  `static let storageKey = AppConfig.Storage.Keys.currencyPreference`, `static let logCategory = LogCategory.currency`;
  `storedValue: String`; `init(storedValue: String?)`; `resolved(systemCode: String) -> String`; `fixedCode: String?`.

## Invariants

- `storedValue` is the word `AppConfig.Storage.systemChoiceValue` for `.system`, else the code
  (`CurrencyPreference.swift:storedValue`).
- `init(storedValue:)` yields `.system` for `nil` and for any code not in `AppConfig.Currency.offered`; only an offered
  code becomes `.fixed`, so a currency this build no longer offers follows the region (`CurrencyPreference.swift:init(storedValue:)`).
- `resolved(systemCode:)` returns the fixed code or the region's; `fixedCode` is `nil` while following the region.
  Nothing is converted between currencies (`CurrencyPreference.swift:resolved(systemCode:)`).

## Side Effects

- None; persistence belongs to the `ChoiceStore` driven by [the parent](../EGM.md).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Currency`).
