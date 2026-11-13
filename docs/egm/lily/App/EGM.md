# App

Source: `lily/App/`

## Overview

The composition root of iskra (code name lily): the only place in the app that knows concrete types; everywhere else
a caller depends on a protocol. `LilyApp`, the `@main` App, builds one `AppDependencies` through `makeDefault()`,
installs `LilyAppDelegate` for the UIKit push callbacks, mounts `AppRootView` and attaches `ShellCommands`.
`AppDependencies.swift` holds the stored collaborators, the memberwise `init` and `makeDefault` (which reads the launch
arguments once); `AppDependencies+Repositories.swift` holds `Repositories`, which binds every protocol to either the
remote set over one `URLSessionAPIClient` or the in-memory mock set, `AuthWiring` and the data-layer factories. The other
`+Area.swift` files add the store factories, argument parsing, the helper structs `GroupRepositories`,
`GroupDependencies`, `AttachmentDependencies`, `PushDependencies`, the preview root `makeMock` and one
`make*ViewModel` factory per screen. Every literal read here is declared in [Config](../Config/EGM.md).

## Interface

- `LilyApp` (`lily/App/LilyApp.swift:LilyApp`): `@main struct LilyApp: App`; `@UIApplicationDelegateAdaptor(LilyAppDelegate.self)`;
  `private let dependencies = AppDependencies.makeDefault()`; body `WindowGroup { AppRootView(dependencies:).tint(Color.lilyAccent) }`
  with `.commands { ShellCommands(dependencies:) }`.
- `LilyAppDelegate` (`lily/App/LilyAppDelegate.swift:LilyAppDelegate`): `didFinishLaunching` sets
  `UNUserNotificationCenter.current().delegate = self` and calls `LaunchAnimations.freeze()`; the token and failure
  callbacks forward to `PushEventRelay.shared.deliver(token:)` and `.fail(_:)`; the `nonisolated` notification-center
  methods answer `[.banner, .sound, .list]` and route `PushPayload.tap(from:)` to `PushEventRelay.shared.notificationTapped(_:)`.
- `AppRootView` (`lily/App/AppRootView.swift:AppRootView`): `init(dependencies:)` seeds `@State sync`;
  body is `MainTabView(dependencies:, showsContent: showsShell)` (the terms sheet and its yield machinery were removed
  2026-11-08 — owner decision: the app never prompts to accept terms) keyed by `navigation.shellGeneration` under `LandingView`
  keyed by `language.language` while `!showsShell`, with `.errorPopup(dependencies.errorCenter)`,
  then `.motionProvider()` outermost (`lily/Core/UI/Layout/MotionPreference.swift`), so every sheet reads `\.motion` too;
  `private struct SyncKey { phase; userID; language }` keys `.task(id:) { await sync.run(active:user:) }`.
- `ShellCommands` (`lily/App/ShellCommands.swift:ShellCommands`): new event Cmd-N (`navigation.requestCreate(.game)`),
  new group Cmd-Shift-N (only if `AppConfig.FeatureFlags.groups`), new tournament Cmd-Shift-T (only if
  `AppConfig.FeatureFlags.tournaments`), Cmd-1 to Cmd-N select `AppTab.shown`; `private func inShell(_:)` gates every action.
- `AppDependencies` (`lily/App/AppDependencies.swift:AppDependencies`): `final class` storing the services typed by their
  protocols and the stores and controllers by their concrete types: the session (`authService`, `tokenProvider?`, `sessionController`, `identity`), the data
  layer (`eventRepository`, `profileRepository`, `profile: ProfileStore`, `feedbackRepository`, `interactionRecorder`, `locationService`, `geocoder` (`GeocodingService`, default `MockGeocodingService()` so tests need no wiring),
  `eventFilterStore`, `eventChanges`, `listSnapshots: any ListSnapshotStore`), `logger`, `errorCenter`, `freezesAurora`, `language: LanguageStore`,
  `currency: CurrencyStore`, `groups: GroupDependencies`, `push: PushDependencies`, `navigation = AppNavigation()`,
  `private(set) lazy var lists: ShellLists`. The `sessionStore` parameter feeds `SessionController` and is not stored.
- `init(logger:sessionStore:authService:tokenProvider:sessionExpiry:identity:eventRepository:profileRepository:feedbackRepository:interactionRecorder:locationService:geocoder:groupRepositories:pushRegistrar:deviceRepository:language:currency:eventFilterStore:listSnapshots:errorCenter:freezesAurora:defaults:)`
  (`lily/App/AppDependencies.swift:AppDependencies.init`): optionals default to `nil`, the stores to the `NoOp*` types;
  builds `SessionController`, sets `identity.session`, builds `ProfileStore`, `GroupDependencies` and `PushDependencies`, calls `finishWiring(recorder:expiry:)`.
- `static func makeDefault(arguments: [String] = AppConfig.LaunchArguments.isHonored ? CommandLine.arguments : [], defaults: UserDefaults = .standard, apply: @escaping (AppLocale.Context) -> Void = AppLocale.set) -> AppDependencies`
  (`lily/App/AppDependencies.swift:AppDependencies.makeDefault`): `startsFresh(arguments:logger:)` (`+Session.swift`), then
  the `make*` factories below, `makeAuthService`, `makeRepositories`, `makeLocationService`, `makeGeocoder` (`+Repositories.swift`), `makeErrorCenter`, `freezesAurora`.
- `static func mockAuthBehavior(from: [String]) -> MockAuthBehavior?` (`lily/App/AppDependencies+Repositories.swift:AppDependencies.mockAuthBehavior`);
  `makeAuthService(arguments:store:language:logger:) -> Auth` binds `MockAuthService` (`tokenProvider: nil`, `expiry: nil`) or `CognitoAuthService(client: AmplifyCognitoClient(logger:), ...)`
  as `AuthService`, `AuthTokenProvider` and `SessionExpiryReporter` (`struct AuthWiring { service; tokenProvider?; expiry? }`, internal, in the same file); `makeLocationService(arguments:logger:)` binds `MockLocationService()` or
  `CachedLocationService(upstream: CoreLocationService(logger:), logger:)`; `makeRepositories(arguments:identity:tokenProvider:logger:) -> Repositories`.
- `struct Repositories` (`lily/App/AppDependencies+Repositories.swift:Repositories`): `events`, `profile`, `feedback`, `interactions`,
  `groups: GroupRepositories`, `devices`, `pushRegistrar`. `remote(baseURL:realtimeEndpoint:identity:tokenProvider:logger:)`
  binds the `Remote*` set over one `URLSessionAPIClient` plus `SystemPushRegistrar`;
  `mock(identity:logger:autoReplies:mockPicker:systemPush:eventsFailFirst:deletedUser:)` binds the `Mock*` set,
  `NoOpInteractionRecorder()` and `SystemPushRegistrar` only when `systemPush`, else `MockPushRegistrar`.
- `GroupRepositories` (`lily/App/AppDependencies+Groups.swift:GroupRepositories`): `groups`, `invites`, `inbox`, `me`,
  `moderation`, `chat`, `users`, `tournaments`, `tournamentInvites`, `realtimeTransport`,
  `makeRealtimeEndpointProvider: @MainActor (MeStore) -> any RealtimeEndpointProvider`, `attachmentUploader`,
  `mediaPreparer`, `attachmentSession: URLSession`. `remote(client:realtimeEndpoint:identity:tokenProvider:logger:)` binds the
  `Remote*Repository` set, `AppSyncRealtimeTransport(socket: URLSessionEventsSocket(), tokenProvider:, logger:)`,
  `RemoteRealtimeEndpointProvider(override:me:)`, `URLSessionAttachmentUploader`,
  `DeviceMediaPreparer`, `URLSession(configuration: .default)`;
  `mock(identity:logger:events:profiles:autoReplies:mockPicker:deletedFixtures:)` (the Bools default to
  false; `deletedFixtures` adds the deleted-flagged chat, tournament and inbox fixtures, 2026-11-08)
  binds the `Mock*Repository` set, `MockRealtimeTransport`, `FixedRealtimeEndpointProvider(url: AppConfig.Realtime.mockEndpoint)`,
  `MockAttachmentUploader(store:)` and `MockAttachmentURLProtocol.makeSession()`.
- `GroupDependencies` (`lily/App/AppDependencies+Groups.swift:GroupDependencies`): `init(repositories:identity:tokenProvider:errorCenter:logger:snapshots:)`
  builds `MyGroupsStore` (the one reader of `snapshots`, which is not stored), `MeStore`, `InboxStore`, `BlockListStore`, `InMemoryChatHistoryCache`,
  `ChatOutbox`, `UnreadCenter`, `ChatCatchUp`, `AttachmentDependencies`, `RealtimeSessionController`; stores `repositories: GroupRepositories`
  (the root's repository pass-throughs read `groups.repositories.<name>`; it has no forwarders of its own); `pasteboard: any Pasteboard = SystemPasteboard()`;
  `sessionObservers` is `[myGroups, me, inbox, blocks, chatHistory, outbox, unreadCenter, attachments.loader,
  attachments.cache, realtime]` (the loader drains its downloads before the cache sweeps).
- `AttachmentDependencies` (`lily/App/AppDependencies+Chat.swift:AttachmentDependencies`): `cache: DiskAttachmentCache`,
  `loader: AttachmentLoader`, `uploader`, `preparer`. `PushDependencies` (`lily/App/AppDependencies+Push.swift:PushDependencies`):
  `registrar`, `devices`, `opener: EventOpener`, `coordinator: PushCoordinator` (the `TournamentOpener` is built in `init` for the coordinator alone).
- Static parsing and knobs: `apiBaseURL(from:logger:) -> URL`, `url(following:in:logger:) -> URL?`
  (`lily/App/AppDependencies+LaunchArguments.swift:AppDependencies.apiBaseURL`); `realtimeEndpoint(from:logger:) -> URL?`
  (`+Chat.swift`); `makeErrorCenter(arguments:logger:)`, `freezesAurora(arguments:logger:)` (`lily/App/AppDependencies+Knobs.swift`).
- Static store factories, each honouring `startsFresh`: `makeSessionStore` (`+Session.swift`, beside `startsFresh(arguments:logger:)`
  and the instance method `wireSessionExpiry(_ reporter: (any SessionExpiryReporter)?)`), `makeLanguageStore`
  (`+Localization.swift`), `makeCurrencyStore` (`+Currency.swift`), `makeEventFilterStore` (`+Events.swift`),
  `makeListSnapshotStore(arguments:startsFresh:directory:logger:)`; instance factories `makeShellSync()` and
  `makeShellLists()` (`lily/App/AppDependencies+Shell.swift:AppDependencies.makeShellLists`).
- View-model factories, one per screen: `makeEventListViewModel(scope:snapshots:)`, `makeLandingViewModel`, `makeEventDetailViewModel`,
  `makeEditEventViewModel`, `makeCreateEventViewModel(onCreated:lockedGroup:)` (`+Events.swift`);
  `makeCreationWizardModel(seed:onCreatedEvent:onCreatedGroup:onCreatedTournament:)`
  (`lily/App/AppDependencies+Create.swift`, 2026-11-10; all three kinds since slice 3, 2026-11-11: builds
  `AppCreationWizardModel` — the file's typealias for
  `CreationWizardModel<CreateEventViewModel, CreateGroupViewModel, CreateTournamentViewModel>`, what call sites
  holding a model name — over `CreationWizardPolicy.opening(for:flags:hasEligibleGroups:)`
  (`.current` flags; the eligible-groups fact read once from `myGroups.eligibleForEvents`, so no walk ever
  follows a groups reload) and
  `CreationWizardFactories`, whose per-kind factories close over `makeCreateEventViewModel`,
  `makeCreateGroupViewModel` and `makeCreateTournamentViewModel` with the caller's created-callbacks and the seed's
  locked group — strong captures, the root outlives every wizard); `makeDiscoverGroupsViewModel`,
  `makeGroupDetailViewModel`, `makeGroupLoaderViewModel`, `makeCreateGroupViewModel`, `makeEditGroupViewModel`, `makeMembersViewModel`,
  `makeInvitePeopleViewModel`, `makeTournamentInvitePeopleViewModel`, `makeReportViewModel` (`+Groups.swift`); `makeChatViewModel`,
  `makeAttachmentComposer`, `makeChatHistoryClearer`, `myGroupsDidChange()`, `myGroupsDidLoad()` (`+Chat.swift`);
  `makeTournamentListViewModel(scope:snapshots:)`, `makeTournamentDetailViewModel`, `makeCreateTournamentViewModel`,
  `makeEditTournamentViewModel` (`+Tournaments.swift`); `makeInboxViewModel`, `makeUserProfileViewModel`,
  `makeFeedbackViewModel`, `makeDisplayNameViewModel`, `makeAboutViewModel`, `makeDeleteAccountViewModel`
  (`+Inbox`, `+People`, `+Feedback`, `+Profile`; the last builds `DeleteAccountViewModel` over
  `meRepository` and `sessionController` as its `AccountDeletionSession`, 2026-11-07). The
  `+Groups`, `+Chat`, `+Push`, `+Inbox`, `+People` and `+Tournaments` extensions expose their stores and repositories as
  pass-throughs.
- `static func makeMock() -> AppDependencies` (`lily/App/AppDependencies+Mock.swift:AppDependencies.makeMock`):
  `Repositories.mock`, `MockAuthService(delay: .zero)` (its default `.succeed` behaviour; a failing or confirming mock is built through
  `makeDefault(arguments:)`), `MockLocationService()`, a `UserDefaults` suite named
  `AppConfig.Storage.previewSuitePrefix + UUID().uuidString`.

### Launch arguments honoured here

| Argument (`AppConfig.LaunchArguments`) | Effect | Read in |
|---|---|---|
| `-reset-session` | `startsFresh`: clears the session, language, currency, event-filter and list-snapshot stores | `makeDefault` |
| `-start-as-guest` | `store.save(.guest)` | `makeSessionStore` |
| `-app-language <code>` | `LanguageStore(launchChoice:)` | `makeLanguageStore` |
| `-mock-auth`, `-mock-auth-confirm`, `-mock-auth-fail` | `MockAuthService` with `.succeed`, `.requireConfirmation(code: AppConfig.Auth.mockConfirmationCode)`, `.fail(.network)` | `mockAuthBehavior(from:)` |
| `-mock-user-id <sub>` | the mock sign-in's user id (mock auth only) | `makeAuthService` |
| `-mock-location` | `MockLocationService` and `MockGeocodingService` (deterministic geocoding) | `makeLocationService`, `makeGeocoder` |
| `-mock-events` | `Repositories.mock` and `NoOpListSnapshotStore` | `makeRepositories`, `makeListSnapshotStore` |
| `-mock-events-fail`, `-mock-chat-replies`, `-mock-attachment-picker`, `-system-push` | knobs of `Repositories.mock` | `makeRepositories` |
| `-api-base-url <url>` | replaces `AppConfig.API.baseURL` | `apiBaseURL(from:logger:)` |
| `-realtime-endpoint <url>` | `RemoteRealtimeEndpointProvider(override:)` | `realtimeEndpoint(from:logger:)` |
| `-hold-popups` | `ErrorCenter(autoDismissDelay: nil)` | `makeErrorCenter` |
| `-freeze-aurora` | `freezesAurora`, published as `\.auroraFrozen` | `freezesAurora(arguments:logger:)` |

## Invariants

- No `#if DEBUG` appears in this directory; launch arguments reach the root only through `makeDefault`'s default
  parameter `AppConfig.LaunchArguments.isHonored ? CommandLine.arguments : []`, so a release build composes from an
  empty list; `ProcessInfo` is never read (`lily/App/AppDependencies.swift:AppDependencies.makeDefault`).
- `-reset-session` is judged once as `startsFresh` and passed to the five store factories; `init` given nil `language`
  or `currency` builds them without launch arguments (`makeLanguageStore(arguments: [], startsFresh: false, ...)`,
  `makeCurrencyStore(startsFresh: false, ...)`). `identity.session = sessionController` is set before
  `GroupDependencies` is built, since the stores read the caller for their starting snapshot
  (`lily/App/AppDependencies.swift:AppDependencies.init`, `lily/App/AppDependencies+Groups.swift:GroupDependencies.init`).
- `finishWiring` sets `navigation.selectedTab = AppNavigation.startTab(for: sessionController.state)` from the cached
  state, then registers observers in the order `groups.sessionObservers`, `navigation`, `push.coordinator`, the
  recorder, `profile`, `lists`, `listSnapshots`: the loader drains its downloads before the cache sweeps, the
  recorder flushes before the session ends, the snapshots clear last; then `wireSessionExpiry(expiry)` sets the
  reporter's `onSessionExpired` to a closure that holds the controller weakly (the controller owns the service that
  fires it) (`lily/App/AppDependencies.swift:AppDependencies.finishWiring`,
  `lily/App/AppDependencies+Session.swift:AppDependencies.wireSessionExpiry`).
- The data layer is one set, all remote or all in-memory, so a mock run never posts a statistic or registers a
  device: `Repositories.mock` uses `NoOpInteractionRecorder()` and `MockPushRegistrar` unless `-system-push`
  (`lily/App/AppDependencies+Repositories.swift:Repositories.mock`); `-mock-events` forces `NoOpListSnapshotStore()`
  (`lily/App/AppDependencies+Shell.swift:AppDependencies.makeListSnapshotStore`); the mock group set shares one
  `MockGroupRepository`, `MockTournamentRepository`, `MockRealtimeTransport` and `MockAttachmentStore`, and production
  binds `AppSyncRealtimeTransport` over `URLSessionEventsSocket`, its tokens the same `AuthTokenProvider` the API
  client sends (`lily/App/AppDependencies+Groups.swift:GroupRepositories.mock`, `GroupRepositories.remote`);
  `Repositories.mock` builds the event and profile mocks first and hands them to `GroupRepositories.mock(identity:logger:events:profiles:...)`,
  whose `MockUserRepository` reads them for a profile's shared games and the caller's own bio.
- Mock-auth precedence is `-mock-auth-fail`, `-mock-auth-confirm`, then `-mock-auth`; `-mock-user-id` counts only with
  mock auth; Cognito doubles as `AuthTokenProvider`, the mock yields `tokenProvider: nil`
  (`lily/App/AppDependencies+Repositories.swift:AppDependencies.makeAuthService`). A URL argument is honoured only when `URL(string:)`
  has a non-nil `scheme` and `host()` (`lily/App/AppDependencies+LaunchArguments.swift:AppDependencies.url(following:in:logger:)`).
- Only `scope == .upcoming` loads the persisted `EventFilter`; other scopes start from `.everything` with
  `NoOpEventFilterStore()` (`lily/App/AppDependencies+Events.swift:AppDependencies.makeEventListViewModel`). Explore's
  carousels are muted: `discover.reportsSearchFailures = false`, `exploreTournaments.reportsFailures = false`
  (`lily/App/AppDependencies+Shell.swift:AppDependencies.makeShellLists`).
- `AppRootView` builds the shell once under the landing, keyed by `navigation.shellGeneration`; the landing is keyed
  by `language.language`; one `sync.run`
  per `SyncKey` (`lily/App/AppRootView.swift:AppRootView.body`, `AppRootView.SyncKey`).
  The root is the one place `motionProvider()` and `layoutModeProvider()` are applied; the layout provider sits inside
  the sheet modifier, the motion provider outside it (`lily/App/AppRootView.swift:AppRootView.body`).
- Every shell command is a no-op outside the shell and the group and tournament commands exist only under their
  feature flags (`lily/App/ShellCommands.swift:ShellCommands.inShell`); both notification-center callbacks are
  `nonisolated` and only a `PushTap` crosses to the main actor (`lily/App/LilyAppDelegate.swift:LilyAppDelegate`);
  one `AppDependencies` per process (`lily/App/LilyApp.swift:LilyApp`).

## Side Effects

- Process-wide: `UNUserNotificationCenter.current().delegate = self` and `LaunchAnimations.freeze()` at launch
  (`lily/App/LilyAppDelegate.swift:LilyAppDelegate.application(_:didFinishLaunchingWithOptions:)`);
  `LaunchAnimations.resumeAfterFirstFrame()` on the root's `onAppear` (`lily/App/AppRootView.swift:AppRootView.body`);
  `AppLocale.set` handed to `LanguageStore` moves the process-wide locale (`AppDependencies.makeDefault`).
- Push: token, failure and tap go to the singleton `PushEventRelay.shared` (`lily/App/LilyAppDelegate.swift`); no
  `registerForRemoteNotifications` call is in this directory.
- Scene phase: `.background` runs `Task { await dependencies.interactionRecorder.flush() }`; `.task` runs
  `sync.restore()` and, per `SyncKey`, `sync.run(active:user:)`; a change of `myGroups.groups` calls
  `realtime.syncRooms()` and a bump of `myGroups.loadVersion` (a load, never a local change) calls
  `unreadCenter.apply(groups:)` (`lily/App/AppRootView.swift:AppRootView.body`, `lily/App/AppDependencies+Chat.swift`).
- Network clients: one `URLSessionAPIClient` (`lily/App/AppDependencies+Repositories.swift:Repositories.remote`);
  `URLSession(configuration: .default)`, `URLSessionAttachmentUploader`, `DeviceMediaPreparer`
  (`lily/App/AppDependencies+Groups.swift:GroupRepositories.remote`); the mock set registers
  `MockAttachmentURLProtocol.serve(_:)` (`GroupRepositories.mock`).
- Disk: `DiskAttachmentCache(logger:)` (`lily/App/AppDependencies+Chat.swift:AttachmentDependencies.init`);
  `FileListSnapshotStore(directory: FileListSnapshotStore.defaultDirectory, logger:)` under Caches, `clear()` when
  `startsFresh` (`lily/App/AppDependencies+Shell.swift:AppDependencies.makeListSnapshotStore`).
- `UserDefaults`: `UserDefaultsSessionStore.clear()` when fresh and `save(.guest)` under `-start-as-guest`
  (`lily/App/AppDependencies+Session.swift:AppDependencies.makeSessionStore`); the language, currency and event-filter
  stores `clear()` when fresh (`+Localization.swift`, `+Currency.swift`, `+Events.swift`); `makeMock` creates a new suite per call.
- State: `finishWiring` sets `navigation.selectedTab`, registers observers on `sessionController` and sets the expiry
  reporter's hook, which spawns `Task { await controller?.endExpiredSession() }` over a weak controller when the pool
  refuses to refresh the token (`lily/App/AppDependencies+Session.swift`); `makeShellLists`
  mutates the new view models' failure-reporting flags.
- Logging through `OSLogLogger()`: `.auth` for `-reset-session`, mock auth, the mock user id and guest mode;
  `.events`, `.chat`, `.push`, `.groups` for each mock knob (`AppDependencies.makeRepositories`); `.network` for a
  base-URL override or a malformed URL; `.chat` for a realtime-endpoint override; `.localization` for the language
  argument; `.ui` for `-hold-popups` and `-freeze-aurora` (`lily/App/AppDependencies+Knobs.swift`).

## Verification

- Run: `./scripts/ci.sh unit` (the suites for this directory are `lilyTests/App/AppDependencies*Tests.swift` and `lilyTests/App/PrivacyManifestTests.swift`, which pins `lily/PrivacyInfo.xcprivacy` from the bundle).
