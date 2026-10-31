# iskra (lily) Blueprint

This file is the Elephant-and-Goldfish Model (EGM) root contract of the repository: the architectural boundaries,
the invariants that cross them and the side effects that leave the process. `README.md` is the human introduction,
`AGENTS.md` the engineering rules for every session, `docs/notes/` the dated engineering notes. Per-directory
contracts live beside the code for `scripts/` and, for everything under `lily/`, mirrored under `docs/egm/lily/`
(the app folder may hold only Swift sources and catalogs; Xcode ships every other file in the app bundle).

## System Overview

iskra is a meetup-style iOS app for sport events: find events near you, join one in a tap, run a group with its own
chat, enter or set up a tournament. iOS 26+, SwiftUI, Liquid Glass, dark only. This repository is the app; business
logic and data live in the Spring Boot backend Laurel (`https://api.iskra.red`, repository `iris-dc/laurel`) and the
AWS resources are defined in the CDK repository rose (`iris-dc/rose`, eu-central-1). Identity stays in Amazon
Cognito (user pool `lily-users`, client `lily-ios`, email + password through Amplify Swift): the app sends the Cognito
access token as `Authorization: Bearer <token>`, the backend validates it and reads the user id from `sub`; the app
keeps no credentials of its own. Guests read `GET /api/events?scope=upcoming` and `GET /api/events/{id}` without a
token; everything else answers 401.

```
 LilyApp (@main) -> AppDependencies (composition root, lily/App)
   |- Config: AppConfig, AppBranding, DesignTokens, AccessibilityIdentifiers   (constants, no state)
   |- Core:   SessionController (Cognito via Amplify) . URLSessionAPIClient -> Laurel (HTTPS, Bearer)
   |          RealtimeSessionController over RealtimeTransport (NoRealtimeTransport in production until the
   |            AppSync Events client lands; the mock bus in debug) . PushCoordinator (APNs)
   |          ErrorCenter / AppError . ContentFreshness / ChangeTracker / ListSnapshotStore (Caches/)
   |          AppLocale / localized(_:) . AppNavigation . LayoutMode and the shared SwiftUI components
   '- Features: Landing, SignIn, Shell -> Events, Groups, Chat, Inbox, People, Tournaments, Profile, Feedback,
                Moderation   (Views -> ViewModels -> Interfaces -> Implementations -> Laurel)
 scripts/ci.sh: lint, build, unit, ui, ui-ipad, all, build-and-unit, archive-products, restore-products,
                ui-shard N|ipad   (GitHub Actions: build-and-unit, archive-products, then restore-products
                and ui-shard in every shard job)
```

## Subdirectories & System Boundaries

- lily (the app target): [`./docs/egm/lily/EGM.md`](./docs/egm/lily/EGM.md) - the whole app: `App` (composition
  root, the only place that knows concrete types), `Config` (every constant and string), `Core` (eighteen shared
  areas) and `Features` (twelve features split by layer). Child contracts: [`App`](./docs/egm/lily/App/EGM.md),
  [`Config`](./docs/egm/lily/Config/EGM.md), [`Core`](./docs/egm/lily/Core/EGM.md),
  [`Features`](./docs/egm/lily/Features/EGM.md).
- scripts: [`./scripts/EGM.md`](./scripts/EGM.md) - `ci.sh` (the local and CI entry point: lint, build-for-testing,
  unit, UI and iPad stages, `UI_SHARDS`, `require_executed_tests`, logs and `.xcresult` bundles under
  `build/results/`), `l10n-check.py` (validates the two string catalogs against every `localized(...)` literal and the
  pbxproj usage descriptions), `make-app-icon.swift` (renders the app icon).
- lilyTests, lilyUITests: test targets (Swift Testing suites by area with fakes in `lilyTests/Support`; XCUITest
  classes by area with `LilyUITestCase`), not contracted here. docs: `docs/notes/` holds the dated engineering notes
  and `docs/egm/` these contracts.

## Global Invariants

- **Composition root.** Only `lily/App/AppDependencies` (+ its `+Area` files) names concrete types; every other
  caller depends on a protocol in an `Interfaces/` folder, with implementations in `Implementations/`. The exceptions
  are `PushEventRelay`, the process-wide relay that `LilyAppDelegate`, `SystemPushRegistrar` and `PushCoordinator`
  share by design, and the push openers (`EventOpener`, `TournamentOpener`) the coordinator owns.
- **One owner per state.** `SessionController` owns `SessionState` (signedOut, guest, signedIn) and is the one place
  that mutates it; `ErrorCenter` is the one funnel for user-facing errors and `AppError` the one typed failure, mapped
  to copy only in `ErrorMessageMapper`; `MyGroupsStore` is the one source of the caller's groups, `InboxStore` of the
  inbox, `ChatHistoryCache` the room truth the realtime controller and `ChatViewModel` both write; `AppNavigation` the
  one navigation state; `AppLocale` the one process-wide locale.
- **Session first.** The first frame shows the cached session from `SessionStore`; `restore()` verifies it with Cognito
  once per process, and `ShellSync.run` and the tab loads join that check before loading anything for a user.
  Sign-out clears every `SessionObserver` (stores, caches, paths, snapshots) before the pool is told.
- **Backend rules on every call.** Repositories build an `APIRequest` and call `send(_:failingWith:)`; backend
  `{code, message}` bodies map to `AppError` (`BackendErrorCode` exhaustive), 401 to `.sessionExpired`, 429 to
  `.rateLimited`; every request carries `X-App-Version`; debug builds may send `X-Local-User-Id` to a local Laurel.
  Writes repeat one `TRY_AGAIN` (`LostRace.attemptTwice`, `WriteGate`), a write with an unknown outcome refetches
  before any popup, creates are idempotent by client id (`CreateFlow`, `clientEventId`, `clientMessageId`).
  Repositories themselves send exactly once; the repeat lives in the callers.
- **Cache before network.** Lists reload only on `ContentFreshness` rules and `ChangeTracker` bumps, start from the
  last answer on disk (`ListSnapshotStore`, a hint, never the truth) and never poll; the first Explore request waits
  up to `AppConfig.Location.firstFixWait` for the position (`HeadStart`).
- **Wire tolerance.** Wire types keep the backend's key names, omit optionals, read and write ISO-8601 instants and
  tolerate new enum values through `WireNamedKind` with `case unknown(String)`.
- **Isolation.** The app target compiles with default `@MainActor` isolation; data types are `nonisolated` and
  `Sendable`; every `extension AppConfig/AppBranding/DesignTokens/AccessibilityIdentifiers/ErrorMessageMapper/String`
  in its own file is a `nonisolated extension`; generated asset symbols are main-actor only.
- **Copy and constants.** Every string is read through `localized(...)` in `AppBranding` or `ErrorMessageMapper`
  (seven languages: en, ru, es, fr, uk, pl, pt; keys are the English text); numbers live in `AppConfig` and
  `DesignTokens`; identifiers in `AccessibilityIdentifiers`, mirrored by hand in the UI tests.
- **Feature flags and launch arguments.** Groups, chat and tournaments are on in debug and Staging, off in Release
  (`AppConfig.FeatureFlags`), read by the callers that show or route to them (Shell, Groups, Events, the Landing
  intro slides, `ShellCommands`, `AppNavigation`) and, for the chat flag, by `TournamentDetailViewModel`; launch arguments
  (`AppConfig.LaunchArguments`) are read in debug builds only.
- **Folder hygiene.** `lily/` holds only Swift sources, `Assets.xcassets` and the two string catalogs; new files join
  their target through synchronized folder groups with no `.pbxproj` edit.

## Global Side Effects

- **Network.** HTTPS to Laurel (`AppConfig.API.baseURL`: `http://localhost:8080` for a debug simulator run,
  `https://api.iskra.red` otherwise) through one `URLSessionAPIClient`; Cognito through Amplify
  (`CognitoAuthService` over `AmplifyCognitoClient`, the only file importing Amplify); attachment bytes PUT to and GET from presigned S3 URLs
  (`URLSessionAttachmentUploader`, `AttachmentLoader`); the realtime seam (`RealtimeSessionController` over
  `RealtimeTransport`: production binds `NoRealtimeTransport()` until the AppSync Events client lands,
  `AppConfig.Realtime.productionEndpoint` is `nil`; the mock bus runs in debug); usage statistics posted in batches
  (`RemoteInteractionRecorder`, flushed when the scene goes to the background).
- **Device.** Caches under `Caches/` (`FileListSnapshotStore` list snapshots, `DiskAttachmentCache` within a byte
  limit, both cleared with the session); UserDefaults for the session cache and the Profile choices
  (`UserDefaultsChoiceStore`), Explore's filter (`UserDefaultsEventFilterStore`) and the last push registration
  (`PushCoordinator`); the `tmp/AttachmentPreviews` QuickLook copies; CoreLocation one-shot fixes; the
  pasteboard; APNs registration and `UNUserNotificationCenter` permission through `SystemPushRegistrar`, the
  `PushRegistrar` that `PushCoordinator` drives (`MockPushRegistrar` in mock runs).
- **Process-wide state.** `UIView.setAnimationsEnabled(false)` from launch until the shell's first frame commits
  (`LaunchAnimations`, with a fallback timer); `AppLocale.current` behind a `Mutex`; `PushEventRelay.shared`;
  `os.Logger` lines by `LogCategory`, ids only, never secrets, names, query text or tokens.
- **Tooling.** `scripts/ci.sh` writes logs and `.xcresult` bundles under `build/results/`, boots and warms up
  simulators, switches the simulator's hardware keyboard off before UI stages, and runs SwiftLint and the two Python
  checks.

## System Verification

- Run: `./scripts/ci.sh all` (what CI runs: lint, build for testing, unit, ui, ui-ipad; the UI stages take about half
  an hour on a Mac)
- Run: `./scripts/ci.sh unit` (lilyTests, Swift Testing, seconds) and `./scripts/ci.sh lint` (SwiftLint strict, the
  l10n check, the UI-shard check, the test-gate self-check)
