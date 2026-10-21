# iskra (code name `lily`): engineering guide

This file holds the rules that apply in every session: what the app is, how to build and test it, how the code is
organised, and the conventions that bite. It is written for coding agents and developers alike and is read by every
agent tool (Claude Code imports it from `CLAUDE.md`). Dated engineering notes, decisions, lessons and the evidence
behind them live in `docs/notes/` (index at the end); **read the note for the area you are about to touch, and write
new facts there, dated, not here.** `README.md` is the short human introduction and stays short.

## The product

iskra is a meetup-style iOS app for sport events: find events near you, join one in a tap, run a group with its own
chat, enter or set up a tournament. iOS 26+, SwiftUI, Liquid Glass, dark only for now. The display name is iskra
(`INFOPLIST_KEY_CFBundleDisplayName = iskra`, `AppBranding.name`); the Xcode project, targets, module, scheme, folders
and bundle id (`iris.lily`) keep the code name `lily`. Design: modern
and minimalistic, reusable SwiftUI components, consistent spacing and typography, no visual clutter.

Feature flags (`AppConfig.FeatureFlags`): groups, chat and tournaments are on in debug builds only.

## Repositories and backend

- **lily** (this repository): the iOS app. The only git repository is the project root; `lily/` is a source folder,
  not a repo.
- **Laurel** (`/Users/makshr/laurel`, GitHub `iris-dc/laurel`): the Spring Boot 4 backend. Business logic and data
  live there (DynamoDB on demand, S3 for attachments). One small ECS Fargate task behind an ALB at
  `https://api.iskra.red`. It has its own `CLAUDE.md`, Gradle build and GitHub Actions.
- **rose** (`/Users/makshr/rose`, GitHub `iris-dc/rose`): the CDK infrastructure (eu-central-1): Cognito user pool
  `lily-users` with client `lily-ios`, the Fargate service, DynamoDB tables, S3, AppSync Events, APNs secret, SNS.
- **Identity stays in Cognito** (email + password through Amplify Swift, configured in code; Apple and Google later).
  The backend never issues credentials: it validates the Cognito **access token** the app sends as
  `Authorization: Bearer <token>` and reads the user id from `sub`. Anonymous reads: `GET /api/events?scope=upcoming`
  and `GET /api/events/{id}`; everything else answers 401 without a token.
- Plans and wire contracts shared with Laurel and rose are under `~/.claude/projects/-Users-makshr-lily/groups-plan/`.

## Build, test and lint

```sh
./scripts/ci.sh lint            # SwiftLint (strict), the l10n check, the UI-shard check, the test-gate self-check
./scripts/ci.sh build           # build for testing
./scripts/ci.sh unit            # lilyTests (Swift Testing; about 2,150 tests in seconds)
./scripts/ci.sh ui              # lilyUITests on an iPhone simulator (about 30 minutes on a Mac)
./scripts/ci.sh ui-ipad         # LilyIPadTests on an iPad simulator
./scripts/ci.sh all             # what CI runs: lint, build, unit, ui, ui-ipad
./scripts/ci.sh build-and-unit  # CI's first job: lint, build for testing, unit (the workflow then runs archive-products)
./scripts/ci.sh ui-shard 2      # one CI UI shard (1..4 or ipad) from archived products, no rebuild
```

- xcodebuild output is huge: redirect it to a file and grep it. `ci.sh` writes logs and `.xcresult` bundles to
  `build/results/`.
- Run one test with `-only-testing:lilyUITests/LilySmokeTests/<name>` (or `lilyTests/<Suite>`). When the identifier
  matches nothing, xcodebuild still exits 0: confirm a `Test Case '...' passed` line (or Swift Testing's
  `Test run with N tests ... passed`) before trusting a green run. `ci.sh` enforces this (`require_executed_tests`).
- Unit and UI tests run with `-parallel-testing-enabled NO`. The command line needs `-skipPackagePluginValidation`
  (Amplify pulls in `smithy-swift`, whose plug-in xcodebuild refuses to validate non-interactively).
- UI tests type into fields, so the simulator's software keyboard must be on; `ci.sh` switches Simulator.app's
  "Connect Hardware Keyboard" off before the UI stage.
- A new UI test class joins a shard in `UI_SHARDS` in `scripts/ci.sh` (the one with the least runner time); a new
  shard also needs its number in the workflow's `shard:` matrix. `ci.sh lint` fails on a class in no shard or in two,
  and on a matrix that misses a shard. `LilyIPadTests` runs only on an iPad and is in no shard.
- If `xcrun` cannot find `simctl`, `xcode-select` points at the Command Line Tools: ask the user to run
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- The GitHub runner is two to three times slower than a Mac; see the UI-test rules below.

## Working rules

**Architecture.** Small services behind interfaces: every piece of business logic is a small single-purpose service,
callers depend on a protocol, never on a concrete type. Interfaces and implementations live in separate folders
(`Interfaces/` and `Implementations/`). One responsibility per function; split what grows. No duplication: look for
what already does it, extract shared logic. Constants and configuration live in `Config/` (`Config/AppConfig.swift` and its `+Area` files non-visual,
`DesignTokens` visual, `AppBranding` copy, `AccessibilityIdentifiers`); no magic strings or numbers inline. Folders
group by feature and layer (`Features/<Feature>/{Models,Interfaces,Implementations,ViewModels,Views,State,Services}`,
`Core/<Area>`).

**Cost (AWS).** Cache locally first and hit the network only when data is stale or missing; never poll in a loop.
Serverless and pay-per-use; question every new resource on cost. Batch and debounce network calls.

**Distributed systems.** The backend runs on several hosts: no shared in-memory state; racing writes use conditional
writes or atomic counters; handlers are idempotent where a client might retry (client-chosen ids such as
`clientEventId`, `clientMessageId`); local caches are hints, never the truth.

**Errors.** Every user-facing error goes through the shared popup (`ErrorCenter`, mounted once on the root; a sheet
that can report errors mounts `.errorPopup` itself, the topmost mount draws). Errors are typed (`AppError`) and mapped
to copy in one place (`ErrorMessageMapper`). Failures are logged with enough context to reproduce.

**Logging.** One facade behind an interface (`Logging`, `LogCategory`). Log what a debugging session will need:
auth (sign-in success and failure, sign-out, token refresh), events (create, join, leave, capacity reached), chat
(connection open and close, send failure), network (failures with status and endpoint), cache (hit, miss,
invalidation); ids only, never secrets, names, query text or tokens. A refusal the screen expects logs at warning, a fault at
error. Log lines are pinned by tests as count plus fragment, never whole sentences; grep `lilyTests` before rewording.

**Testing.** All business logic has unit tests; services take interfaces so fakes stand in (`lilyTests/Support`).
Everything runs without AWS credentials. Watch for retain cycles, unreleased observers, unclosed clients. Swift
Testing suites run concurrently in one process: never touch a process-wide folder another suite's sign-out sweeps,
inject the folder. Compile-time traps: `#require(items.first(where: \.flag))` does not compile (write the closure),
a `try` inside `#expect(...)` or to the right of `&&` must be hoisted, `Attachment` collides with Swift Testing's type
(write `lily.Attachment`), and `NavigationPath.count` needs `import SwiftUI`.

**Repository etiquette.** Commit only when the user asks, one commit per repository. Never `git checkout <file>` to
undo your own edit in a dirty tree: it drops the user's uncommitted work on that file too; edit it back instead.

## Before every commit

1. Spawn a review agent to review all uncommitted changes deeply.
2. It checks and, where needed, fixes: simplicity and readability; no redundancy; interfaces and implementations in
   separate folders; constants in config files; logic covered by passing tests; no memory or connection leaks;
   distributed-systems safety; errors reach the shared popup; key events logged; everything runs locally; **every UI
   change checked as rendered on a simulator**, not only by reading the code; `README.md` and the `docs/notes/`
   file of the area reflect the change.
3. Refactor and re-run until the review passes, then run `./scripts/ci.sh all`.
4. Only then commit, and only when the user asks.

## Where things live

- `lily/App/`: `LilyApp`, `LilyAppDelegate` (the UIKit push callbacks), `AppRootView` (wiring only), `ShellCommands`
  (keyboard shortcuts) and `AppDependencies` (+ extension files per area), the **only place that knows concrete
  types**.
- `lily/Config/`: `AppConfig` (API paths and base URLs, limits, `LaunchArguments`, `FeatureFlags`, `Cognito`),
  `AppBranding` (every string, through `localized`), `DesignTokens`, `AccessibilityIdentifiers`; each extension
  file is a `nonisolated extension` (see Conventions).
- `lily/Core/`: `Networking` (`APIClient`, `APIRequest`, `URLSessionAPIClient`, `send(_:failingWith:)`,
  `WriteGate`, `CreateFlow`, `LostRace`), `Auth`, `Realtime`, `Navigation` (`AppNavigation`, the tab paths),
  `Changes` (`ContentFreshness`, `StoreLoader`, `ChangeTracker`), `Concurrency` (`SingleFlight`, `Deadline`,
  `SlotGate`, `DetachedWork`, `Sleep`), `Localization` (`localized(_:)`, `AppLocale`, `LanguageStore`), `Currency`,
  `Preferences`, `Location`, `Statistics`, `Push`, `Errors` (`AppError`, `ErrorCenter`, `ErrorMessageMapper` + its
  per-area files), `Logging`, `Validation` (`CredentialsValidator`, `String.wireLength`, `Collection.first(of:)`),
  `System` (`Calendar.nextFullHour`, `FileManager.removeItemIfPresent`), `Foundation` (`String.trimmed` and
  `nonBlankTrimmed`, how every typed field is read), `UI` (`Components`, `Layout`, `Effects`, `Theme`, `Interfaces`).
- `lily/Features/`: `Landing`, `SignIn`, `Shell` (`ShellSync` in `Services` runs the per-user loads), `Events`,
  `Groups`, `Chat`, `Inbox`, `People`, `Tournaments`, `Profile`, `Feedback`, `Moderation`.
- `lilyTests/`: Swift Testing suites by area; `Support/` holds the fakes, fixtures and harnesses (`FakeAPIClient`,
  `StubBackend`, `GroupHarness`, `RealtimeHarness`, `TournamentHarness`, `PushHarness`, `SpyLogger`, `HeldSleep`,
  `DateClock`, `RequestHold`).
- `lilyUITests/`: `LilyUITestCase` (launch and primitives) + `LilyUITestCase+Screens` (screen helpers), and one class
  per area; the test target mirrors the app's identifier and launch-argument literals, since it cannot import the app.
- `scripts/`: `ci.sh`, `l10n-check.py` (+ its unittest), `make-app-icon.swift`.
- The full tree with one line per file group: `docs/notes/folder-layout.md`.

**Who owns what.** `SessionController` owns the session state machine (`SessionState`: signedOut, guest, signedIn).
The first frame shows the cached choice from `SessionStore`, no network answer awaited; `restore()` then verifies it
with Cognito once per process and settles a disagreement (a pool without a session ends the cached one like a
sign-out, a pool session the cache missed signs in, an unreachable pool keeps the cache and the backend's 401 decides).
`ShellSync.run`, Home's and Chats' loads join that check first, so nothing loads for a user the pool has not confirmed;
the start tab is picked from the cached state in `AppDependencies.init`. `ErrorCenter` is the one funnel for errors.
`EventListViewModel` owns a list (scopes `upcoming`, `joined`, `group`) and reloads on `ContentFreshness` rules and
`ChangeTracker` bumps; `EventDetailViewModel` owns the event on screen and the join/leave rules (`Participation`).
`MyGroupsStore` is the one source of the caller's groups (rooms and conversations are groups of kind `tournament` and
`direct`; `communities` leaves them out). The chat room cache (`ChatHistoryCache`) is the truth the realtime controller
and `ChatViewModel` both write. `InboxStore` is the one source for the inbox. `LayoutMode` (compact, regular, wide) is
how every adaptive view decides, never the device.

## Conventions that bite

- **Concurrency.** The app target compiles with default `@MainActor` isolation; the test targets do not. Mark test
  suites `@MainActor` (nested harness types need their own annotation) and plain data types `nonisolated` so they stay
  `Sendable`. Every `extension AppConfig/AppBranding/DesignTokens/AccessibilityIdentifiers/ErrorMessageMapper/String`
  in its own file must be a `nonisolated extension`, or its members become main-actor isolated and the build only
  warns; after a build check `grep "/lily/.*: warning:" build/results/build.log` prints nothing.
- **Generated asset symbols** (`Color.lilyAccent`, `Image(.googleLogo)`) are main-actor isolated: use them from
  views and other main-actor types only, never from a `nonisolated` type.
- **Synchronized folder groups.** New files under `lily/`, `lilyTests/`, `lilyUITests/` join their target with no
  `.pbxproj` edit. Info.plist is generated: plist keys are `INFOPLIST_KEY_*` build settings. **`lily/` holds only
  Swift sources, `Assets.xcassets` and the two string catalogs**; anything else ships inside the app bundle.
  `find lily -type f ! -name '*.swift' ! -name '*.xcstrings' | grep -v Assets.xcassets` must print nothing.
  Entitlements live at the repository root (`lily.entitlements` for Release, `lily.debug.entitlements` for Debug).
- **SwiftLint (strict, `.swiftlint.yml`).** Line 130/160, function body 40/60, type body 200/300, file 300/400,
  cyclomatic complexity 10/15 (switch cases count, computed properties are not checked), at most five parameters,
  `empty_count` (write `isEmpty`), `empty_collection_literal` (no `== []`), `empty_string` (no `== ""`), two closure
  arguments must both be labelled. Fix violations, never disable rules. Split a type at the limit into
  `+Area.swift` extension files; stored properties stay in the main file and go internal for the extension.
- **Localisation.** Every string is read through `localized(...)` in `AppBranding` or `ErrorMessageMapper` as a
  `static var` or a function, never a `static let`. Keys are the English text; interpolations are `%lld` / `%@` with
  plural variations in the catalog; a key shared by two roles with different grammar gets a role key with an explicit
  `en` value. The catalogs (`lily/Localizable.xcstrings`, `lily/InfoPlist.xcstrings`) are hand-maintained JSON that a
  Python `json` round trip (indent 2, `ensure_ascii=False`, no sorting, trailing newline) reproduces byte for byte.
  `scripts/l10n-check.py` (in `lint`) requires every literal to match one key, every key to be used and every language
  present. Languages: en, ru, es, fr, uk, pl, pt; `-app-language <code>` for a run.
- **Wire types** keep the backend's key names, omit optionals (never `null`), read and write ISO-8601 instants, and
  tolerate new enum values: `WireNamedKind` with `case unknown(String)` (`EventType`, `SkillLevel`, `MessageKind`,
  `GroupKind`, `InboxItemKind`, `AttachmentKind`). Hand-written `init(from:)` only where a missing key needs a
  default. Contract samples for Laurel's JSON are `ContractSamples` (declared in `lilyTests/Support/NetworkingDoubles.swift`,
  extended per area in the `*Fixtures.swift` and `AttachmentDoubles.swift` files) and are pinned by tests.
- **Launch arguments** (`AppConfig.LaunchArguments`, debug builds only): `-reset-session`, `-start-as-guest`,
  `-mock-location`, `-mock-auth`, `-mock-auth-confirm`, `-mock-auth-fail`, `-mock-events`, `-mock-events-fail`,
  `-mock-chat-replies`, `-mock-attachment-picker`, `-mock-terms-pending`, `-hold-popups`, `-freeze-aurora`,
  `-system-push`, and the value-taking `-app-language <code>`, `-api-base-url <url>`, `-mock-user-id <sub>`,
  `-realtime-endpoint <url>`. UI tests launch with `-reset-session -mock-location -mock-auth -mock-events
  -freeze-aurora -app-language en` and must keep passing without a backend.
- **Code comments** carry a short "why" only: no dates, review references or "until then" narrative. Dated history
  belongs in `docs/notes/`.
- **Mocks mirror the backend's rules** (`MockEventRepository`, `MockGroupRepository`, `MockChatRepository`,
  `MockTournamentRepository`, ...): the same refusals and orders as Laurel, fixtures around Berlin
  (`AppConfig.Location.mockCenter`), so the simulator shows realistic distances.

## UI and design rules

- Every content screen starts with `ContentScreen { ... }` (the aurora at content strength under the content); the
  landing draws `AuroraBackground` itself. There is no launch screen of our own: the system's generated one covers the
  process start and the first frame is the landing or the shell. Never put one aurora behind the `TabView` with
  transparent screens. The aurora, the grain and the fade-in follow the wall clock (`AuroraGeometry`, `FilmGrain`,
  `AuroraReveal`); phases are reduced modulo their period in `Double` before becoming `Float`.
- Design language: SF Pro only with tight tracking, accent `#B72734` (`LilyAccent`) over maroon `#5E0C26`, the aurora
  core frozen at `#B31B3F`, amber as a sparing secondary, Liquid Glass surfaces, dark only, native iOS 26 buttons.
  Chat bubbles are plain fills, never glass. The decisions the user made by eye are in `docs/notes/design-and-ui.md`;
  do not revisit them without new evidence.
- Buttons go through `lilyProminentButton(sizing:)` / `lilyGlassButton(sizing:labelColor:)`, text-only buttons are
  `.borderless` with `tappableLabel()`, chips through `lilyChip(_:)`; nothing puts a `frame` on a capsule label.
  Filter criteria live in dropdown panels, never as a chip row on a screen.
- iOS 26 layering: a toolbar item draws its own glass capsule, so a segmented `Picker` in one needs
  `.sharedBackgroundVisibility(.hidden)`; the tab bar floats, so only a full-bleed `Map` ignores the bottom safe
  area, with overlays as siblings in a `ZStack`.
- A container that carries an `accessibilityIdentifier` needs `.accessibilityElement(children: .contain)` first, or
  the identifier is stamped on every child and overrides theirs.
- Sheets that are forms use `lilyFormSheet()`, `readableColumn()` and their own `.errorPopup`.
- Adaptive layout switches on `LayoutMode` from the window's size class; compact must stay pixel-identical to the
  iPhone screens. Rows never size themselves with `containerRelativeFrame` (the iPad sidebar is a safe-area inset);
  measure usable width (`UsableWidth`).
- Verify every UI change on a simulator, by screenshot; for motion, record (`xcrun simctl io <udid> recordVideo`) and
  cut frames with ffmpeg. The recipe is in `docs/notes/build-test-and-simulator.md`.

## Simulator and UI-test rules

- **Never touch CoreSimulatorService with `launchctl` or `pkill`**; it broke the simulator for a whole login session.
  If runtimes show as unavailable, ask the user to reboot. A single device whose `simctl launch` or `terminate` hangs
  is fixed by `xcrun simctl shutdown <udid>` and `boot`.
- **Never seed app state with `simctl spawn <udid> defaults write`**; use the launch arguments. A device preference the
  run itself changed (the keyboard language) may be reset that way: `defaults write com.apple.keyboard.preferences
  KeyboardLastUsed -string "en_US@sw=QWERTY;hw=Automatic"`, then shut down and boot.
- UI tests: `waitForExistence`, never `exists` right after an action; type through `enter(_:into:)`; long-press menus
  through `openContextMenu(on:until:)`; a `Form` row below the fold is not in the accessibility tree
  (`scrollUntilHittable`, `dragUpUntilExists`); a `confirmationDialog` is `app.sheets.firstMatch`; menu items are
  found by identifier; the iPad's tabs are plain buttons (`openTab(titled:)` handles both); map annotations are queried
  from `app`, not `app.maps`; a `Toggle` in a `Form` is one element whose `tap()` lands on the label; `typeText`
  bypasses autocorrect and inline predictions, so a test that needs them taps `app.keys[...]`.
- Screenshots from a test: a throwaway `@objc` test writes `XCUIScreen.main.screenshot().pngRepresentation` to the
  directory in `TEST_RUNNER_SHOT_DIR`, set as a prefix of the command (`TEST_RUNNER_SHOT_DIR=/tmp/x xcodebuild test
  ...`; written after the action it becomes a build setting and never reaches the runner), with a hardcoded fallback
  directory in the test; delete the test before the gate. `XCUIScreen` blanks `SecureField`s; `simctl io screenshot`
  does not.
- Dynamic Type and language variants: `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`
  and `-app-language <code>` as extra launch arguments.

## Backend essentials

- `AppConfig.API.baseURL`: debug on the simulator `http://localhost:8080`, everything else `https://api.iskra.red`;
  `-api-base-url http://<mac-name>.local:8080` points a debug device build at a Laurel on the Mac.
- A local Laurel (`local` profile, DynamoDB Local) trusts `X-Local-User-Id`, which the app sends in debug builds only
  (`AppConfig.API.sendsLocalUserHeader`), never logged; a debug build signed in through Cognito sends a real Bearer
  too, so start Laurel with `COGNITO_USER_POOL_ID=eu-central-1_JmfE31ODT COGNITO_APP_CLIENT_ID=54dul3essertek166u2st78s4a`.
- Repositories build an `APIRequest` and call `client.send(request, failingWith: fallback)`: backend `{code, message}`
  bodies map to `AppError` (`APIFailureMapping`, `BackendErrorCode` exhaustive), 401 to `.sessionExpired`, 429 to
  `.rateLimited`, other `URLError`s to `.network`. Every request carries `X-App-Version`.
- Writes repeat one `TRY_AGAIN` (`LostRace.attemptTwice`, `WriteGate`); a write whose outcome is unknown (`.network`,
  a 5xx) refetches before showing a popup, because Laurel commits before it answers; creates are idempotent by client
  id (`CreateFlow`).

## Documentation rules

- `README.md`: short, for people: what the app is, how it fits together, how to run and test it. No engineering notes.
- `AGENTS.md`: rules that apply in every session. Keep it under about 300 lines; when a fact is specific to one
  area or one date, it belongs in `docs/notes/`.
- `docs/notes/<area>.md`: the dated engineering notes. Append, with the date, the why and the evidence (which test,
  which screenshot). When a later change supersedes an older sentence, add a marker such as "(removed 2026-10-14)"
  rather than rewriting history.
- `CLAUDE.md`: Claude Code specifics only; it imports this file.

## Notes index (`docs/notes/`)

- `build-test-and-simulator.md`: ci.sh internals, shards, the test gate, simulator and XCUITest lessons, screenshot and
  recording recipes, the CI runner's flakes and what fixed them.
- `design-and-ui.md`: the design language as decided with the user, buttons, chips, the aurora and grain, iOS 26
  layering, the intro pager and its slides, the app icon.
- `shell-and-navigation.md`: the tabs and their retitling, `AppNavigation`, where things go in the composition root.
- `auth-and-backend.md`: Cognito through Amplify, the session state machine and its restore rules, the networking
  seam, the wire contract in words, usage statistics, AWS deployment.
- `events.md`: the feed and its filter, join and leave, creating and editing a game, player limits, event types,
  prices and currency, relevance and position staleness, statistics.
- `groups.md`: the groups data layer, view models and screens, roles and invites, games in groups, tolerant kinds.
- `chat.md`: the room cache and realtime controller, chat screens, clearing a chat, replies, attachments (pictures,
  videos, files) and their caps.
- `inbox-people-and-push.md`: the Chats tab and inbox, direct invites, profiles and direct conversations, push
  notifications and the pending Apple Developer account steps.
- `tournaments.md`: entries and teams, brackets and standings, results and disputes, scheduling, invites, contract
  checks against Laurel.
- `localization.md`: the seven languages, the catalog rules, the Russian register pass.
- `ipad.md`: `LayoutMode`, the split Chats view, grids, readable columns, form sheets, the wide landing.
- `profile-and-feedback.md`: the contact form.
- `deep-review-2026-10.md`: the October 2026 review passes, cluster by cluster (what moved where and why).
- `folder-layout.md`: the full folder tree with a line per file group.
