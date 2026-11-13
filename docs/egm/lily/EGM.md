# lily (the app target)

Source: `lily/`

## Overview

The iOS app target of iskra (module, scheme and bundle id `iris.lily` keep the code name `lily`). The folder holds
only Swift sources, `Assets.xcassets`, the two string catalogs (`Localizable.xcstrings`, `InfoPlist.xcstrings`) and
`PrivacyInfo.xcprivacy` (the privacy manifest, which must ship at the bundle root): Xcode's synchronized folder groups
ship every other file inside the app bundle, which is why these contracts live
under `docs/egm/` and not beside the code. Four top-level folders: `App` is the composition root and the only place
that knows concrete types; `Config` holds every constant, string, token and identifier as `nonisolated` enum
namespaces; `Core` is the shared machinery (auth, networking, realtime, changes and freshness, localisation, UI
components); `Features` holds the twelve user-facing features, each split by layer; the eight that own a data layer
keep protocols in `Interfaces/` and concrete types in `Implementations/` (Landing, Shell and SignIn have
neither).

The target compiles with default `@MainActor` isolation; plain data types are `nonisolated` so they stay `Sendable`,
and every `extension AppConfig/AppBranding/DesignTokens/AccessibilityIdentifiers/ErrorMessageMapper/String` in its
own file is a `nonisolated extension`. Groups, chat and tournaments keep named switches in `AppConfig.FeatureFlags`,
plain `true` in every configuration since the AppSync transport landed. Everything runs without AWS credentials behind the mock set that
`-mock-auth -mock-events` selects. Unit suites: `lilyTests/` (`./scripts/ci.sh unit`); end-to-end: `lilyUITests/`
(`./scripts/ci.sh ui`, `ui-ipad`).

## Subdirectories & Boundaries

- App: [`./App/EGM.md`](./App/EGM.md) - `LilyApp` (`@main`) builds one `AppDependencies` through `makeDefault()`,
  installs `LilyAppDelegate` for the UIKit push callbacks (token and taps to `PushEventRelay.shared`,
  `LaunchAnimations.freeze()` at launch), mounts `AppRootView` (one task per scene phase and user drives `ShellSync`)
  and attaches `ShellCommands`. `AppDependencies` binds every protocol to the remote set over one
  `URLSessionAPIClient` or the in-memory mock set, reads the debug-only launch arguments once, and its `+Area`
  extensions hold the store and view-model factories.
- Config: [`./Config/EGM.md`](./Config/EGM.md) - `AppConfig` (API paths and base URLs, limits mirrored from Laurel,
  `LaunchArguments`, `FeatureFlags`, `Cognito`), `AppBranding` (every user-facing string as a computed `static var` or
  `static func` through `localized(_:)`, the English text being the catalog key), `DesignTokens` (spacing, radii,
  durations, layout, opacity, aurora tuning, SF Symbol names) and `AccessibilityIdentifiers` (a UI test that reads one
  mirrors the literal by hand). Nothing holds state; the only runtime read is `Bundle.main.bundleIdentifier`.
- Core: [`./Core/EGM.md`](./Core/EGM.md) - eighteen single-purpose areas: `SessionController` and the session state
  machine (Auth), `AppError` and `ErrorCenter` (Errors), the networking seam and its retry and idempotency rules
  (Networking), freshness and change tracking (Changes), the concurrency helpers, `RealtimeSessionController`
  (Realtime), `PushCoordinator` (Push), `AppNavigation`, `AppLocale` and `localized(_:)` (Localization), the
  currency and preference stores, location, logging, statistics, validation, the `Foundation` string helpers, system
  seams, and the shared SwiftUI layer (UI: `ContentScreen`, `LayoutMode`, the aurora).
- Features: [`./Features/EGM.md`](./Features/EGM.md) - Landing, SignIn, Shell, Events, Create, Groups, Chat,
  Inbox, People, Tournaments, Profile, Feedback; data flows Views -> ViewModels -> Interfaces -> Implementations ->
  Laurel, with Models shared by every layer; the feature flags are read by the callers that show or route to a
  gated feature (Shell, Groups, Events, Create, Landing, `ShellCommands`, `AppNavigation`) and, for the chat flag,
  by `TournamentDetailViewModel`.
