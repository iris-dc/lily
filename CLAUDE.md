# Lily — Project Guide

Lily is a meetup-style iOS app for sport events. Users sign in, create events, join events, and chat with the other participants of an event. The backend runs on AWS on a tight budget.

## Product Scope

- **Auth**: sign up, log in, log out, session persistence.
- **Events**: create, browse, join, leave. An event has an event type (a sport, or "other"), a required number of participants, a time, and a location, plus optional description, "looking for", level and price.
- **Chat**: one chat room per event, visible only to participants.
- **Design**: modern and minimalistic. Reusable SwiftUI components, consistent spacing and typography, no visual clutter.

## Architecture Principles

- **Small services behind interfaces**. Every piece of business logic lives in a small, single-purpose service. Callers depend on a protocol/interface, never on the concrete type. This keeps code testable and swappable.
- **Interfaces and implementations live apart**. Protocols/interfaces go in their own folder; concrete types go in an `Implementations/` folder. Never mix the two in one place.
- **Small, meaningful functions**. One responsibility per function. If a function or class grows, split it and move the parts to the right folder.
- **No duplication**. Before writing code, look for something that already does it. Extract shared logic into reusable components, helpers, or extensions.
- **Constants and configuration in dedicated files**. No magic strings or numbers inline. Keep them in `Config/AppConfig.swift` (and related files under `Config/`), grouped by domain (API endpoints, cache TTLs, UI spacing, feature limits).
- **Well-organized folders**. Group by feature and by layer (for example `Features/Events/Views`, `Features/Events/Services`, `Core/Networking`, `Core/UI/Components`).

## Cost Discipline (AWS)

- **Cache locally first**. Read from an on-device cache and only hit the network when data is stale or missing. Never poll DynamoDB or other services in a loop.
- **Prefer serverless and pay-per-use**: Lambda, DynamoDB on-demand, API Gateway, Cognito. Avoid always-on compute unless there is a proven need.
- **Batch and debounce** network calls where possible.
- **Question every new AWS resource** on cost before adding it.

## Distributed-Systems Correctness

The backend may run on multiple hosts at once. Every design must hold under that assumption:

- No in-memory state that must be shared across requests. Shared state lives in DynamoDB or another shared store.
- Writes that can race (joining an event when seats are limited) use conditional writes or atomic counters.
- Handlers are idempotent where a client might retry.
- Local caches are treated as hints, never as the source of truth.

## Error Handling

- The iOS app surfaces every user-facing error through the **existing shared error popup component**. Do not create new alert styles per screen.
- Errors are typed and mapped to user-friendly messages in one place.
- Failures are logged with enough context to reproduce them.

## Logging

Log the key events that a future debugging session would need:

- Auth: login success/failure, logout, token refresh.
- Events: create, join, leave, capacity reached.
- Chat: connection open/close, send failure.
- Network: request failures with status code and endpoint.
- Cache: hit, miss, invalidation.

Use a single logging facade (behind an interface) so the sink can change without touching call sites. Never log secrets or PII.

## Testing

- All business logic is covered by unit tests. Services depend on interfaces so they can be tested with fakes.
- The project must be runnable and testable locally without AWS credentials (use local fakes or mocks for AWS-backed services).
- Verify there are no memory leaks (retain cycles, unreleased observers) or connection leaks (unclosed sockets, streams, or clients).

## Workflow: Before Every Commit

1. **Spawn a review agent** to deeply review all uncommitted changes.
2. The agent must check and, where needed, fix:
   - Simplicity and readability. Small functions, clear names.
   - No redundancy. Shared logic is extracted and reused.
   - Interfaces and implementations are in separate folders.
   - Constants and config are in dedicated config files.
   - Logic is covered by tests and tests pass.
   - No memory or connection leaks.
   - Distributed-systems safety (see section above).
   - Errors reach the user via the shared popup.
   - Key events are logged.
   - Everything runs and tests locally.
   - Any UI change is checked as rendered on a simulator, not only by reading the code. Static review has missed layering and safe-area bugs that a screenshot showed immediately.
   - `README.md` reflects the current state of the project.
3. Refactor and re-run tests until the review passes.
4. Only then commit.

## Documentation

- Keep `README.md` current: setup, how to run locally, how to run tests, folder layout, AWS deployment steps.
- Document architectural decisions briefly when they are non-obvious.

## Backend

- **Identity stays in Cognito** (Apple, Google, email + password). The backend never issues credentials; it validates Cognito JWTs (`spring-boot-starter-security-oauth2-resource-server` against the user-pool JWKS) and reads the user id from the `sub` claim. The iOS `AuthService` interface is shaped 1:1 after Amplify.Auth for this reason.
- **Business logic and data live in Laurel**, a Java Spring Boot 4 backend in its own repository (`/Users/makshr/laurel`, GitHub `iris-dc/laurel`) with its own `CLAUDE.md`, Gradle build and GitHub Actions on a Linux runner; iOS CI stays on macOS. It validates Cognito JWTs with `spring-boot-starter-security-oauth2-resource-server`, stores data in DynamoDB (on-demand), and is meant for one small ECS Fargate task while traffic is low (watch idle cost against Lambda + SnapStart). Its `GET /api/me` returns the caller's `sub`; the token type the app sends (id vs access token) is still to be decided together with the backend.

## Notes for AI Agents

Facts that cost time to learn and are not obvious from the code:

- **Build and test with `./scripts/ci.sh [lint|build|unit|ui|all]`.** SwiftLint runs in strict mode from `.swiftlint.yml`; fix violations rather than disabling rules. It picks a simulator, writes logs and `.xcresult` bundles to `build/results/`, and is exactly what GitHub Actions runs. If `xcrun` cannot find `simctl`, `xcode-select` has fallen back to the Command Line Tools; ask the user to run `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- **Never touch CoreSimulatorService with `launchctl` or `pkill`.** It broke the simulator for the whole login session once and required a reboot. If runtimes show as unavailable, ask the user to reboot.
- **Never seed app state with `simctl spawn <udid> defaults write`.** The value lands outside the app container: the app can read it but not clear it, and test clones inherit it. Use the launch arguments in `AppConfig.LaunchArguments` instead (`-reset-session`, `-start-as-guest`, `-mock-location`, `-mock-auth-fail`). UI tests already pass them.
- **UI tests run with `-parallel-testing-enabled NO`.** Simulator clones intermittently failed to launch the test runner.
- **The UI test class is `LilySmokeTests` in the `lilyUITests` target**, so one test is `-only-testing:lilyUITests/LilySmokeTests/<name>`. When the identifier matches nothing, `xcodebuild` still exits 0 and prints a passing suite, so confirm a `Test Case '...' passed` line for your test actually appears before trusting a green run. Map annotations are not descendants of the map element in the accessibility tree: query them from `app`, not from `app.maps`.
- **No `.pbxproj` edits are needed for new files.** The project uses synchronized folder groups; anything under `lily/`, `lilyTests/`, `lilyUITests/` joins its target automatically. Info.plist is generated, so plist keys go in as `INFOPLIST_KEY_*` build settings (the location usage text is one).
- **Keep `lily/` to Swift sources and `Assets.xcassets`.** The flip side of synchronized groups: every other file in there joins the app target and is copied into the app bundle. Stray copies of `README.md`, a CI workflow and `.claude/settings.local.json` once shipped inside `lily.app`; a stray `.git` copy in the same folder made Xcode write 171 lines of `.git/...` membership exceptions into the project file to keep those out. `.gitignore` does not protect you, because Xcode reads the filesystem and not the index. Check with `find lily -type f ! -name '*.swift' | grep -v Assets.xcassets`, which should print nothing.
- **The only git repository is the project root.** `lily/` is the app source folder, not a repo. A leftover `.git` copy inside it made `git status` report every tracked file as deleted and the source folders as untracked, which looks like catastrophic loss and is not. Run git from the root or with `-C`, and if a status shows mass deletions, check `git rev-parse --show-toplevel` before believing it.
- **Concurrency:** the app target compiles with default `@MainActor` isolation and approachable concurrency; the test targets do not. Mark test suites `@MainActor`, and mark plain data types `nonisolated` so they stay `Sendable` and usable from tests.
- **Asset symbols are generated:** colorsets are `Color.lilyAccent`, `Color.lilySecondary`, `Color.lilySurface`, `Color.lilyInk`, ... and images `Image(.googleLogo)`. Add a colorset, get the symbol. They are compiled into the app module, so they are `@MainActor`-isolated: reference them only from views and other main-actor types, never from a `nonisolated` enum or struct.
- **Design language, decided with the user:** SF Pro only with tight tracking (a serif wordmark was tried and rejected), red accent `#B72734` (`LilyAccent` and `AccentColor`; coral `#FF6363` became dark raspberry `#B31B3F` on 2026-09-09, then was nudged "a tiny bit rustier" to `#B72734` the same day; a brighter `#E8285F` was rejected as too pink) over maroon `#5E0C26` (`LilyAccentDeep`); the aurora core is frozen at the raspberry `#B31B3F` in `LilyAuroraCore` so the background stays put when the accent moves, with amber as a sparingly used secondary, Liquid Glass surfaces, dark only for now (the light theme was removed on 2026-09-09 via `INFOPLIST_KEY_UIUserInterfaceStyle = Dark`; colorsets keep their light variants), native iOS 26 large buttons (50pt; see the Buttons note below). The landing sells the product and enters the app as a guest in one tap; sign-in is optional and lives in a sheet, reached from a full-width glass "Sign in" button centred under the primary one (2026-09-11, replacing the "Already have an account? Sign in" text link at the user's request; a caption-plus-compact-pill and a text-only button were built and judged and lost). `EventTypeChip` and the preview card's icon sit as glass on glass cards on purpose: Apple advises against nesting Liquid Glass, but the render is clean and was approved by eye; revisit only if it ever looks muddy. Removed on 2026-09-09 at the user's request: the Search tab (with the client-side filtering behind it; "I don't need it"), the Explore subtitle "Games near you this week.", and the wordmark on the landing (it stays on the launch screen). Added on 2026-09-11 at the user's request: a sport filter chip row on Explore (chips, not the text search that was removed); the user then redirected (same day): the filter must be a **menu of criteria**, not a chip row on the page, so the chip row was removed and a toolbar `Menu` replaced it; the same day the user asked for a **dropdown** with a price *input* and *dates*, which a `Menu` cannot host, so `EventFilterButton` now drops `EventFilterPanel` down as a popover (kept a popover on iPhone): event-type chips inside the panel are fine, a chip row on the page is not. Also from that request: "Sport" became "Event type" everywhere (`EventType` with an `other` case, `EventTypeChip`), the default distance is 10 km, the price cap is typed in, and a date range can be set. The reference point for distance is the user's position for now; a chosen place is the intended next step and `EventFilter.maxDistanceMeters` is already judged against an arbitrary origin. Events gained optional details on 2026-09-11 at the user's request: description, "who they are looking for exactly" (free text), skill level and price; all optional, `nil` by default, with `Price` and `SkillLevel` models. The capacity bar's track went faint (same day, user request): `.quaternary` had read as a full grey bar, so an empty game looked full. The label under it now counts joined players the way the bar fills ("N of M joined") instead of "N of M spots left". On Profile the guest section sits directly on the screen at `DesignTokens.Layout.screenMargin` so its heading lines up with the large title; a card there had put the text 24pt further right.
- **To see what a screen actually looks like**, add a temporary XCUITest that writes `XCUIScreen.main.screenshot().pngRepresentation` to a directory passed in as `TEST_RUNNER_<VAR>=...` (the simulator can write host paths); it must be an environment variable of the xcodebuild process, `TEST_RUNNER_SHOT_DIR=/tmp/x xcodebuild test ...` (the prefix is stripped, the test reads `SHOT_DIR`). Written after the action as `TEST_RUNNER_SHOT_DIR=/tmp/x` it becomes a build setting (the log lists it under "Build settings from command line") and never reaches the runner, which cost a session an hour on 2026-09-11; keep a hardcoded fallback directory in the test so a misrouted variable still yields screenshots. Or drive the app by hand and use `xcrun simctl io <udid> screenshot`. Note that `XCUIScreen` screenshots blank out `SecureField` contents, which looks like a rendering bug; `simctl` shows them. Crop with `sips -c H W --cropOffset Y X` (no Python PIL on this Mac). Delete the throwaway test afterwards.
- **iOS 26 layering, both learned from real bugs:** every toolbar item draws its own glass capsule, so a segmented `Picker` inside one needs `.sharedBackgroundVisibility(.hidden)` on the `ToolbarItem`, otherwise it renders two backgrounds and two outlines. The tab bar floats above content, so a full-bleed map must let only the `Map` ignore the bottom safe area, with overlays kept as siblings in a `ZStack`; `.ignoresSafeArea(edges: .bottom)` on the container pins bottom overlays to the screen edge, under the tab bar.
- **Animating with `TimelineView` dates:** `context.date.timeIntervalSinceReferenceDate` is about 8e8 s. A phase like `Float(time / period * 2π)` lands near 1e8-3e8, where one `Float` step is 8-32 rad, so `sin` of it is constant for a minute and then jumps; the aurora shipped static because of this and nobody noticed for days. Reduce modulo the period in `Double` first (`time.truncatingRemainder(dividingBy: period)`), then convert. `AuroraGeometry.angle(at:period:)` does this; reuse it. Byte-identical `simctl` screenshots taken seconds apart are the quick test.
- **Buttons:** every glass or prominent capsule goes through `lilyProminentButton(sizing:)` / `lilyGlassButton(sizing:labelColor:)`, and nothing puts a `frame` on such a label: the old `frame(minHeight: 48)` on the label rendered ~62pt capsules, because the style adds its own padding. Text-only buttons are `.borderless` and get their 44pt hit area from `tappableLabel()`; tappable cards, pins and the popup's dismiss stay `.plain`. Chips share `lilyChip(_:)` for their metrics (`EventTypeChip` badge, the price chip on cards); `EventMapPin` takes its selected look from `LilyTheme.selectionGlass`/`selectionLabelColor` (accent glass + white label when on, plain glass + ink when off) and is a 40pt circle whose selection the `Map` owns. Filter criteria live in the dropdown `EventFilterPanel`; `ChoiceChip` is for multiple choice inside such panels, never for a chip row on a screen (rejected by the user 2026-09-11). `.glass` colours its label from the tint, so a glass button that should read as ink (landing "Sign in", provider buttons) passes `labelColor: .lilyInk` and "Sign out" keeps the accent. `ContentUnavailableView` actions use `.fitted` or they squash into a blob.
- **Every content screen starts with `ContentScreen { ... }`** (aurora at content strength under the content); the landing and launch screens draw `AuroraBackground` themselves at their own intensity.
- **Where things go:** `App/AppDependencies.swift` is the only place that knows concrete types. `SessionController` owns the session state machine. `ErrorCenter` is the single funnel for user-facing errors. `AppBranding` holds product copy (`AppBranding.Events` the shared event copy: capacity, price, level, "Looking for"; `AppBranding.Events.Filter` the filter panel), `AppConfig` non-visual constants, `DesignTokens` visual ones. `LocationUpdateSource` is the seam in front of CoreLocation and `CachedLocationService` the only place a location result is remembered. `MyEventsContent` decides what the My Events tab shows for a session state.
- **Sheets need their own popup mount.** `.errorPopup` on the root view renders under any presented sheet, so a sheet that can report errors (the sign-in sheet) mounts `.errorPopup(errorCenter)` itself and takes the `ErrorCenter` explicitly; `ErrorCenter` tracks the mounts and only the topmost one draws, so the error is not shown twice.
- **Nested test harness types need their own `@MainActor`.** A struct nested inside a `@MainActor` test suite does not inherit the isolation; annotate it or the compiler rejects calls into main-actor app types.
- **Fixtures are geographic:** mock events are scattered around `AppConfig.Location.mockCenter` (Berlin). Set the simulator location there to see realistic distances.
- **Before committing, follow the workflow above:** spawn the review agent, run `./scripts/ci.sh all`, keep `README.md` current. Only commit when the user asks.
