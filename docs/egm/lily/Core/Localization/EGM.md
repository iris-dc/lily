# Localization

Source: `lily/Core/Localization/`

## Overview

How copy is read in the app's language and how numbers, dates and plural rules follow its locale, for the whole process.
`AppLocale` holds the one process-wide `Context` behind a `Mutex`, because copy is read from `nonisolated` types
(`AppBranding`, `ErrorMessageMapper`, the models) that have no way to an instance; `LanguageStore` loads the user's
choice, applies it to `AppLocale` and publishes it to the views, which re-render without a relaunch; `localized(_:)` is
the one function every string goes through. The language and preference types are in `Models/`.

## Interface

- `localized(_ key: String.LocalizationValue) -> String` (`lily/Core/Localization/Localized.swift:localized`): `nonisolated`
  global function; `String(localized:bundle:locale:)` with `AppLocale.current`'s bundle and locale.
- `AppLocale` (`lily/Core/Localization/AppLocale.swift:AppLocale`): `nonisolated enum`; `static var current: Context`,
  `static var locale: Locale`, `static func set(_ context: Context)` (the bundle is read through `current.bundle`). Nested
  `Context: Sendable`: `init(language: AppLanguage?, mainBundle: Bundle = .main, current: @escaping @Sendable () -> Locale = { .autoupdatingCurrent })`;
  `language: AppLanguage?`, `bundle: Bundle`, `locale: Locale`; `static locale(for: AppLanguage, current: Locale) -> Locale`.
- `LanguageStore` (`lily/Core/Localization/LanguageStore.swift:LanguageStore`): `@Observable final class` (main-actor);
  `init(store: any ChoiceStore<LanguagePreference>, launchChoice: AppLanguage? = nil, systemChoice: @escaping () -> AppLanguage = { AppLanguage.systemChoice() }, apply: @escaping (AppLocale.Context) -> Void = AppLocale.set, logger: any Logging)`;
  `private(set) var preference: LanguagePreference`, `language: AppLanguage`, `context: AppLocale.Context`;
  `locale: Locale`; `select(_ preference: LanguagePreference)`.
- Children: [Models](./Models/EGM.md).

## Invariants

- `AppLocale.state` is a `Mutex<Context>` (`Synchronization`) starting at `Context(language: nil)`; `current` and `set`
  take the lock, so any isolation may read copy (`AppLocale.swift:state`, `current`, `set`).
- `Context.bundle` is the fixed language's `.lproj` bundle when the build carries it, else `.main` (also for the system
  choice, so iOS applies the user's preferred languages and its English fallback). `Context.locale` is derived on every
  read: the live `.autoupdatingCurrent` while the system chooses, or the fixed language's code set over the current
  locale's components with the script cleared (region, calendar, hour cycle and units kept), so a Region change reaches
  prices and distances without a relaunch (`AppLocale.swift:Context.bundle`, `Context.locale`, `locale(for:current:)`).
- `localized` keys are the English text, so a language without the translation falls back to English; a
  `String.LocalizationValue` interpolation becomes the catalog's `%lld` or `%@` placeholder with the language's plural
  rules (`Localized.swift:localized`).
- `LanguageStore.init`: `launchChoice` (the `-app-language` argument) is used as `.fixed` for this run and never stored,
  else `store.load()`; `context` is built from `preference.fixedLanguage`, applied, and `language` resolved against the
  system choice. `select` is a no-op for an equal preference; otherwise it saves, rebuilds and applies the context, then
  updates `language`, so the store and `AppLocale` never disagree (`LanguageStore.swift:init`, `select`).

## Side Effects

- Process-wide state: `AppLocale.set` replaces the shared `Context` (called by `LanguageStore` at init and on select).
- Persistence through `store.save(_:)` on select (a `ChoiceStore<LanguagePreference>`, keyed by
  `LanguagePreference.storageKey`); `store.load()` at init (`LanguageStore.swift`).
- Logging under `.localization` at info: `"Language <code> (system|chosen)"` at init and `"Language changed to <code> (...)"`
  on select (`LanguageStore.swift`).
- Reads `Bundle.main.path(forResource:ofType: "lproj")` when a fixed language is chosen (`AppLocale.swift:Context.init`).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Localization`).
