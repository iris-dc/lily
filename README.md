# Lily

Meetup-style iOS app for sport events: sign in, create and join events, chat with participants.
iOS 26+, SwiftUI, Liquid Glass, dark-only design (for now) with a dark-raspberry accent over maroon. Backend will run on AWS (Cognito, API Gateway, Lambda, DynamoDB) on a tight budget.

## Status

Initial skeleton. Auth and events are **mocked**; no AWS resources exist yet.

- Landing screen that explains the product (headline, live preview of upcoming events) with one tap into the app. Sign-in (Apple / Google / Email) is optional and lives in a sheet.
- Tabbed shell (Explore, My Events, Profile, Search) fed by fixture events. Explore switches between a list (with distance from the user) and a map with one glass pin per event; selecting a pin shows a preview card that opens the event detail.
- Session persistence across relaunch (guest choice and mock session).
- Shared error popup, typed errors, logging facade, unit tests for all business logic.

## Requirements

- Xcode 26.6 or newer, iOS 26.5 simulator runtime.
- No AWS credentials needed to run or test.

## Run

Open `lily.xcodeproj`, select an iPhone simulator, run the `lily` scheme.

From the command line:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # only if xcode-select points at the Command Line Tools
xcodebuild -scheme lily -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Test

```sh
xcodebuild -scheme lily -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Tests use Swift Testing and fakes for every interface (`lilyTests/Support/TestDoubles.swift`).
UI smoke tests in `lilyUITests/` launch the real app with the `-reset-session` and `-mock-location` arguments (see `AppConfig.LaunchArguments`; `-start-as-guest` skips the landing) and walk the landing → Explore and landing → sign-in sheet → mock Apple → Explore paths, plus the Explore map: switching list → map, and selecting a pin, which asserts the preview card stays clear of the floating tab bar.

Run everything the way CI does:

```sh
./scripts/ci.sh          # lint, build-for-testing, unit tests, UI tests
./scripts/ci.sh unit     # or: lint | build | unit | ui
```

Linting uses [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`) with the rules in `.swiftlint.yml`; CI runs it in strict mode, so every warning fails the build.

Logs and `.xcresult` bundles land in `build/results/`.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs on every push and pull request to `main` on a `macos-26` runner: it selects the newest Xcode 26, then runs `scripts/ci.sh` in four steps (lint, build, unit tests, UI tests) and uploads the result bundles as an artifact. The runner needs Xcode 26.5 or newer because the deployment target is iOS 26.5.

To make the mock auth fail and see the error popup, pass `behavior: .fail(.network)` to `MockAuthService` in `AppDependencies.makeDefault()` (previews can use `AppDependencies.makeMock(authBehavior: .fail(.network))`).

## Folder layout

```
lily/
  App/           LilyApp (entry), AppRootView (state switch), AppDependencies (composition root)
  Config/        AppConfig (non-visual constants), DesignTokens (spacing, radii, durations, SF Symbol names)
  Core/
    Auth/        Models, Interfaces (AuthService, SessionStore), Implementations (Mock*, UserDefaults*), SessionController
    Errors/      AppError, ErrorMessageMapper (single copy source), ErrorCenter (drives the popup)
    Logging/     Logging facade + OSLogLogger
    Location/    Coordinate model, LocationService interface, CoreLocation and mock implementations
    Validation/  CredentialsValidator
    UI/          Theme (fonts, aurora role-to-color mapping), Effects (aurora geometry, roles, film grain: pure, testable math),
                 Components (aurora background, glass cards, button modifiers, provider buttons, error popup, wordmark, ...)
  Features/
    Landing/     First screen: headline, event preview deck, primary action (Views + ViewModels)
    SignIn/      Sign-in sheet with provider buttons and the email form (Views + ViewModels)
    Shell/       MainTabView
    Events/      Models, Interfaces, Implementations (mock repository), ViewModels, Views
    Profile/     Guest and signed-in profile
lilyTests/       Mirrors the above; Support/ holds fakes and fixtures
lilyUITests/     LilySmokeTests: end-to-end walks against the real app in a simulator
scripts/         ci.sh, the single entry point for lint, build and tests
.github/         GitHub Actions workflow
```

The Xcode project uses synchronized folder groups: any file added under `lily/`, `lilyTests/` or `lilyUITests/` joins the matching target automatically. The other side of that convenience is that **`lily/` must contain only Swift sources and `Assets.xcassets`** — any other file there is copied into the app bundle, and `.gitignore` does not prevent it, because Xcode reads the filesystem rather than the git index.

Rules: interfaces and implementations live in separate folders, constants live under `Config/`, every user-facing error goes through `ErrorCenter`, every log line goes through `Logging`.

## Architecture notes

- **Session state machine.** `SessionController` owns `SessionState` (`loading`, `signedOut`, `guest`, `signedIn`). Views only read it; all transitions are methods on the controller.
- **Auth interface mirrors Amplify.Auth.** `restoreSession`, `signIn(with:)`, `signUp`, `signOut` map 1:1 to `fetchAuthSession`, `signInWithWebUI` / `signIn(username:password:)`, `signUp`, `signOut`, so `CognitoAuthService` will replace `MockAuthService` without touching callers.
- **SessionStore is a hint, not truth.** In production it only stores the guest choice; Amplify keeps tokens in the Keychain. The mock also stores its fake session there.
- **Branding lives in `Config/AppBranding.swift`:** app name, landing headline and copy, button titles. Change them there and every screen follows.
- **Colors** are asset catalog colorsets with light and dark variants, exposed via generated symbols (`Color.lilyAccent`, `Color.lilySecondary`, `Color.lilySurface`, ...). Dark raspberry `#B31B3F` is the accent, maroon `#5E0C26` the deep tone behind it; amber (`lilySecondary`) is used sparingly for sport chips, the hero badge and the "nearly full" capacity state.
- **Location:** `LocationService` returns one fix or `nil`; the app never blocks on it. `CoreLocationService` uses `CLLocationUpdate.liveUpdates`, which prompts for when-in-use permission (usage text is set as an `INFOPLIST_KEY_` build setting). Events carry a `Coordinate`; distance is computed on-device with a haversine, no network.
- **Typography:** SF Pro only, with tight tracking on the wordmark and headline (sizes and tracking in `DesignTokens.Typography`).
- **Aurora background** is a 4x4 `MeshGradient` in a 30 fps `TimelineView`, in the spirit of the Raycast home page: a near-black surface with soft luminous red glows and a whisper of grain. Two maroon masses, upper-left behind the headline and lower-right behind the button, are joined by a thin diagonal with a darker valley on either side (`AuroraPalette.roles`), drawn with bicubic smoothing so no cell edge shows. Corners are pinned, edge points slide along their edge, interior points wander on paths that sum three sines drawn from four incommensurate periods (19, 23, 29, 37 s) with golden-angle phase offsets. The red visibly flows because a brightness ripple travels down the main diagonal every 29 s and a weaker one crosses the other diagonal every 41 s (`AuroraGeometry.cellIntensities`), while the raspberry core, kept on the top edge so its peak never swallows the red headline line, breathes every 23 s. The whole background fades in from nothing over 3.5 s (ease-in-out) when a screen appears. Numbers live in `DesignTokens.Aurora`; the math lives in `Core/UI/Effects` (`AuroraGeometry`, `AuroraPalette`, `FilmGrain`) and is unit tested; `LilyTheme` maps roles to asset colors and the view only draws. Every screen adds live film grain: 12 seeded 128 px noise tiles with a squared distribution (sparse bright speckle, blacks stay black), generated once, drawn at 2 device pixels per noise pixel without interpolation and cycled at 24 fps, blended `plusLighter` at 8%. Content screens draw the mesh at `contentIntensity` (0.55), the landing at 0.85, the launch screen at full strength. Reduce Motion freezes the first frame (the fade-in stays, being a crossfade). The app is forced to dark mode via the `INFOPLIST_KEY_UIUserInterfaceStyle` build setting; colorsets keep their light variants for when the light theme returns. Phases are reduced modulo their period in `Double` before becoming `Float`: `timeIntervalSinceReferenceDate` cast to `Float` only resolves steps of several radians, and the old mesh stood still for a minute at a time.
- **Liquid Glass layering.** Two rules that iOS 26 enforces and that are easy to get wrong. A toolbar item already draws its own glass capsule, so the segmented list/map `Picker` sets `.sharedBackgroundVisibility(.hidden)` on its `ToolbarItem` to avoid a doubled background. The tab bar floats above content, so `EventsMapView` lets only the `Map` ignore the bottom safe area and keeps the selected-event card as a `ZStack` sibling inside the safe area; a UI test asserts the card stays above the tab bar.
- **Provider glyphs:** Apple and Email are SF Symbols in the ink color; Google uses its official multicolor "G" as a vector asset (`GoogleLogo`). The Apple button must meet Apple's Sign in with Apple guidelines (or use `SignInWithAppleButton`) once real auth lands.

## AWS deployment

Not yet. The plan: a Cognito user pool with Apple and Google identity providers (Amplify Swift wired into `AppDependencies.makeDefault()`), then a Java Spring backend on AWS ECS with a database behind it, validating Cognito JWTs and owning events and chat. See `CLAUDE.md` for the reasoning. `amplifyconfiguration.json` is git-ignored.
