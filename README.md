# Lily

Meetup-style iOS app for sport events: sign in, create and join events, chat with participants.
iOS 26+, SwiftUI, Liquid Glass, dark-first design with a red accent. Backend will run on AWS (Cognito, API Gateway, Lambda, DynamoDB) on a tight budget.

## Status

Initial skeleton. Auth and events are **mocked**; no AWS resources exist yet.

- Welcome screen with Apple / Google / Email sign-in and a "Continue without an account" path.
- Tabbed shell (Explore, My Events, Profile, Search) fed by fixture events.
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
    Validation/  CredentialsValidator
    UI/          Theme (fonts, aurora palette), Components (glass cards, button modifiers, provider buttons, error popup, wordmark, ...)
  Features/
    Welcome/     Sign-in entry screen and email sheet (Views + ViewModels)
    Shell/       MainTabView
    Events/      Models, Interfaces, Implementations (mock repository), ViewModels, Views
    Profile/     Guest and signed-in profile
lilyTests/       Mirrors the above; Support/ holds fakes and fixtures
```

The Xcode project uses synchronized folder groups: any file added under `lily/` or `lilyTests/` joins the matching target automatically.

Rules: interfaces and implementations live in separate folders, constants live under `Config/`, every user-facing error goes through `ErrorCenter`, every log line goes through `Logging`.

## Architecture notes

- **Session state machine.** `SessionController` owns `SessionState` (`loading`, `signedOut`, `guest`, `signedIn`). Views only read it; all transitions are methods on the controller.
- **Auth interface mirrors Amplify.Auth.** `restoreSession`, `signIn(with:)`, `signUp`, `signOut` map 1:1 to `fetchAuthSession`, `signInWithWebUI` / `signIn(username:password:)`, `signUp`, `signOut`, so `CognitoAuthService` will replace `MockAuthService` without touching callers.
- **SessionStore is a hint, not truth.** In production it only stores the guest choice; Amplify keeps tokens in the Keychain. The mock also stores its fake session there.
- **Colors** are asset catalog colorsets with light and dark variants, exposed via generated symbols (`Color.lilyAccent`, `Color.lilySurface`, ...).
- **Placeholders to replace before release:** the Google "G" glyph in `ProviderGlyph` is a stand-in for the official asset, and the Apple button must meet Apple's Sign in with Apple guidelines (or use `SignInWithAppleButton`) once real auth lands.

## AWS deployment

Not yet. Next step is a Cognito user pool with Apple and Google identity providers, then Amplify Swift wired into `AppDependencies.makeDefault()`. `amplifyconfiguration.json` is git-ignored.
