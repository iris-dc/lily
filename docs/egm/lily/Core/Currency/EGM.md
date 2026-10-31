# Currency

Source: `lily/Core/Currency/`

## Overview

The currency the user types prices in and judges the price cap in: the one chosen on Profile, else the device region's
(`AppLocale.locale.currency`), else `AppConfig.Currency.defaultCode`. `CurrencyStore` loads the choice at launch through a
`ChoiceStore`, persists it on change and publishes it to the views; prices on events keep their own currency whatever
this says, nothing is ever converted. The choice type is in `Models/`.

## Interface

- `CurrencyStore` (`lily/Core/Currency/CurrencyStore.swift:CurrencyStore`): `@Observable final class` (main-actor).
  `init(store: any ChoiceStore<CurrencyPreference>, systemChoice: @escaping () -> String? = { AppLocale.locale.currency?.identifier }, logger: any Logging)`;
  `private(set) var preference: CurrencyPreference`; `currencyCode: String`; `systemCurrencyCode: String`;
  `select(_ preference: CurrencyPreference)`.
- `ChoiceStore` is the generic preference store in `lily/Core/Preferences/Interfaces/` (external to this directory).
- Children: [Models](./Models/EGM.md).

## Invariants

- `currencyCode` is `preference.resolved(systemCode: systemCurrencyCode)`; `systemCurrencyCode` is the region's code or
  `AppConfig.Currency.defaultCode` when the region names none. Both are derived on every read
  (`CurrencyStore.swift:currencyCode`, `systemCurrencyCode`).
- `select` is a no-op for an equal preference; otherwise it sets `preference`, saves it and logs the code in force
  (`CurrencyStore.swift:select`).

## Side Effects

- Persistence through `store.save(_:)` on select (a `ChoiceStore<CurrencyPreference>`, keyed by
  `CurrencyPreference.storageKey`); `store.load()` at init (`CurrencyStore.swift`).
- Logging under `.currency` at info: `"Currency <code> (system|chosen)"` at init and `"Currency changed to <code> (...)"`
  on select (`CurrencyStore.swift`).
- Reads `AppLocale.locale` (`lily/Core/Localization/AppLocale.swift`) for the region's currency by default.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Currency`).
