# Core

Source: `lily/Core/`

## Overview

The shared machinery every feature of iskra builds on, eighteen areas with no source files at this level. Each area
is small and single-purpose: a protocol in `Interfaces/`, concrete types in `Implementations/`, plain `nonisolated`
value types in `Models/`, and the area's own controller or helpers beside them. Nothing here knows a feature; the
concrete types are wired in `lily/App/AppDependencies` ([`../App/EGM.md`](../App/EGM.md)) and the constants they
read live in `lily/Config` ([`../Config/EGM.md`](../Config/EGM.md)). The features that use them are under
`lily/Features` ([`../Features/EGM.md`](../Features/EGM.md)).

The owners that matter across the app are here: `SessionController` (Auth) owns the session state machine and is the
one place that mutates it; `ErrorCenter` (Errors) is the one funnel for user-facing errors and `AppError` the one
typed failure; `BackendErrorCode.appError` and `APIClient.send(_:failingWith:)` (in `APIFailureMapping.swift`),
`LostRace`, `WriteGate` and `CreateFlow` (Networking) are the rules every backend
call follows; `ContentFreshness`, `ChangeTracker` and `StoreLoader` (Changes) decide when a cached answer is reused;
`RealtimeSessionController` (Realtime) is the one realtime connection; `AppNavigation` (Navigation) the one navigation
state; `AppLocale` and `localized(_:)` (Localization) the one way copy is read; `LayoutMode` (UI/Layout) how every
adaptive view decides. The unit suites live under `lilyTests/<Area>` (`./scripts/ci.sh unit`).

## Subdirectories & Boundaries

- Auth: [`./Auth/EGM.md`](./Auth/EGM.md) - the session state machine: `SessionController` owns `SessionState`
  (`signedOut`, `guest`, `signedIn`), starts from the cached choice in `SessionStore`, verifies it against the Cognito
  pool once per process in `restore()`, holds the single in-flight authentication slot, runs the sign-out protocol
  (observers' last word, then store and state, then the pool) and reports failures through `ErrorCenter`. Children:
  Interfaces, Models, Implementations (`CognitoAuthService` over `AmplifyCognitoClient`, the only file importing
  Amplify).
- Changes: [`./Changes/EGM.md`](./Changes/EGM.md) - when a cached backend answer can be reused and when it must be
  fetched again (`ContentFreshness`), the app-wide change counters (`ChangeTracker`), what a list shows for a state
  (`ListState`), the app-lifetime stores' load bookkeeping (`StoreLoader`), and the snapshot layer that keeps a
  list's last answer on the device (`ListSnapshotStore`, `FileListSnapshotStore`).
- Concurrency: [`./Concurrency/EGM.md`](./Concurrency/EGM.md) - six helpers giving async code its cancellation and
  ordering rules: `Deadline`, `HeadStart`, `SingleFlight`, `SlotGate`, `DetachedWork`, and the injectable `Sleep`.
- Currency: [`./Currency/EGM.md`](./Currency/EGM.md) - the currency the user types prices in and judges the price cap
  in (`CurrencyStore`: the Profile choice, else the device region's, else the default); prices on events keep their
  own currency, nothing is converted.
- Errors: [`./Errors/EGM.md`](./Errors/EGM.md) - `AppError`, the one typed failure (92 cases, `wrapping(_:)`,
  `isCancellation(_:)`); `ErrorCenter`, the one funnel that shows it; `ErrorMessageMapper`, one exhaustive switch
  routing to per-area `nonisolated extension` files.
- Foundation: [`./Foundation/EGM.md`](./Foundation/EGM.md) - `String.trimmed` and `nonBlankTrimmed`, how every typed
  field is read.
- Localization: [`./Localization/EGM.md`](./Localization/EGM.md) - `AppLocale` (the one process-wide locale context
  behind a `Mutex`, readable from `nonisolated` types), `LanguageStore` (loads, applies and publishes the user's
  choice), `localized(_:)` (the one function every string goes through).
- Location: [`./Location/EGM.md`](./Location/EGM.md) - one-shot access to the user's position: the protocol screens
  depend on, framework-free coordinate types, and the CoreLocation, cached and mock services.
- Logging: [`./Logging/EGM.md`](./Logging/EGM.md) - the one log facade (`Logging`, `LogCategory`) and the `os`
  conformer the composition root installs; ids only, never secrets.
- Navigation: [`./Navigation/EGM.md`](./Navigation/EGM.md) - `AppNavigation`: the selected tab, the Home and Chats
  paths, the conversation the Chats split view shows; a sign-out resets every per-user path.
- Networking: [`./Networking/EGM.md`](./Networking/EGM.md) - the seam to Laurel: `APIClient` and
  `URLSessionAPIClient`, `APIRequest`, `APIFailureMapping.swift` (`BackendErrorCode` exhaustive, 401 to `sessionExpired`,
  429 to `rateLimited`), `LostRace` and `WriteGate` (one `TRY_AGAIN` repeat), `LostAnswer` (the read-back after a
  lost answer every write shares), `CreateFlow` (a create whose answer was lost is refetched under its client id, a
  reused id is updated), `ProgressDataTask`.
- Preferences: [`./Preferences/EGM.md`](./Preferences/EGM.md) - how a Profile choice (language, currency) survives a
  relaunch: `ChoiceStore`, `StoredChoice`, `UserDefaultsChoiceStore`, one string per choice.
- Push: [`./Push/EGM.md`](./Push/EGM.md) - `PushCoordinator` keeps Laurel's device registry in step with this device,
  asks for the permission after the user committed to a game, opens the event or match behind a tapped reminder,
  unregisters before a sign-out; failures are logged, never shown.
- Realtime: [`./Realtime/EGM.md`](./Realtime/EGM.md) - `RealtimeSessionController`, the one realtime connection of a
  signed-in foregrounded app: subscribes the user's channel plus the open room and recent groups, applies envelopes
  to the chat room cache and the stores, renews before token expiry, backs off on failures, follows channel epochs and
  recovers over REST what the socket missed.
- Statistics: [`./Statistics/EGM.md`](./Statistics/EGM.md) - usage statistics buffered on the device and posted in
  batches (`InteractionRecorder`, `RemoteInteractionRecorder`, `NoOpInteractionRecorder`); ids, types and flags only,
  never a guest.
- System: [`./System/EGM.md`](./System/EGM.md) - the `Pasteboard` seam, `Calendar.nextFullHour(after:)`,
  `FileManager.removeItemIfPresent(at:)`.
- UI: [`./UI/EGM.md`](./UI/EGM.md) - the shared SwiftUI layer: Components (`ContentScreen`, the button, chip and
  field modifiers, cards, rows, `EmptyStateView`, the shared `errorPopup`, `DraftSheet`), Layout (`LayoutMode`,
  `UsableWidth`, `FlowArrangement`, grids, `readableColumn`, `lilyFormSheet`, tab-bar hiding), Effects (the
  `nonisolated` aurora and grain arithmetic, `LaunchAnimations`), Theme (`LilyTheme`) and Interfaces
  (`DraftSubmitting`).
- Validation: [`./Validation/EGM.md`](./Validation/EGM.md) - client-side checks mirroring the backend's refusals:
  `CredentialsValidator`, `String.wireLength` (UTF-16 units like Java's `String.length()`), `String.codePointCount` and
  `prefix(codePoints:)` (the display name's measure), `Collection.first(of:)`.
