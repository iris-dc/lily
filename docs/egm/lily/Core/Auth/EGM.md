# Auth

Source: `lily/Core/Auth/`

## Overview

The session state machine. `SessionController` owns `SessionState` (`signedOut`, `guest`, `signedIn`) and is the one
place that mutates it: it starts from the cached choice in `SessionStore`, so the first frame shows the right screen with
no network answer awaited; verifies that cache against the pool once per process in `restore()`; holds the single
in-flight authentication slot; runs the sign-out protocol (observers' last word, then store and state, then the pool);
and reports failures through `ErrorCenter`. The email sign-up and confirmation steps live in the `+EmailConfirmation`
extension. Children: the protocols in `Interfaces/`, the value types in `Models/`, the Cognito, mock and store
implementations in `Implementations/`.

## Interface

- `SessionController` (`lily/Core/Auth/SessionController.swift:SessionController`): `@Observable final class`, main-actor.
  `init(authService: any AuthService, sessionStore: any SessionStore, errorCenter: ErrorCenter, logger: any Logging)`.
  Observable read-only state: `state: SessionState`, `authenticatingProvider: AuthProvider.Kind?`. Exposed
  dependencies: `authService`, `logger`.
- Methods (`SessionController.swift`): `restore() async`; `@discardableResult signIn(with: AuthProvider) async -> Bool`;
  `signIn(withEmail: EmailCredentials) async -> EmailAuthResult`; `continueAsGuest()`;
  `addObserver(_: any SessionObserver)`; `signOut() async`; `endExpiredSession() async`;
  `authenticating<Outcome>(_ kind: AuthProvider.Kind, busy: Outcome, _ attempt: () async -> Outcome) async -> Outcome`;
  `performSignIn(with: AuthProvider) async -> EmailAuthResult`;
  `@discardableResult report(_ error: any Error, during step: String, fallback: AppError = .unknown) -> EmailAuthResult`.
- Extension (`lily/Core/Auth/SessionController+EmailConfirmation.swift`), all three `@discardableResult`:
  `signUp(email:password:) async -> EmailAuthResult`; `confirmSignUp(email:code:password:) async -> ConfirmOutcome`;
  `resendConfirmationCode(email:) async -> Bool`.
- Children: [Interfaces](./Interfaces/EGM.md), [Models](./Models/EGM.md), [Implementations](./Implementations/EGM.md).

## Invariants

- Initial state from the cache (`SessionController.swift:state(cached:)`): `.signedIn(session)` gives `.signedIn(user)`,
  `.guest` gives `.guest`, `.signingOut` or nothing gives `.signedOut` (the pool is told on `restore()`).
- `restore()` runs `verifyCachedSession` once per process; a later call awaits the same `restoreCheck` task. A check
  that throws (offline) keeps the cache; a refresh token the pool refuses mid-run reaches `endExpiredSession()` through
  `SessionExpiryReporter.onSessionExpired`, wired by the composition root (`lily/App/AppDependencies+Session.swift`). If
  `state` changed during the check the answer is dropped, and a `.guest` chosen meanwhile is
  saved again (the service writes the store while it checks). Otherwise: the same user is verified; a pool session the
  cache missed or disagrees with sets `.signedIn` and tells observers `sessionDidRestore()`; no pool session over a cached `.signedIn`
  runs `endLocalSession()`; no pool session otherwise changes nothing (`SessionController.swift:verifyCachedSession`).
- One authentication at a time (`SessionController.swift:authenticating`): while `authenticatingProvider` is set another
  attempt returns `busy` with no popup. `signUp` and `confirmSignUp` hold the slot for their whole flow.
- One sign-out at a time (`SessionController.swift:holdingSignOutSlot`, `isSigningOut`); a second caller does nothing.
- Sign-out order (`SessionController.swift:signOut`, `endLocalSession`): await every observer's
  `sessionWillEnd()` while still signed in; then, only if `state` is unchanged, `sessionStore.clear()`,
  `state = .signedOut`, `sessionDidEnd()` to observers; last `authService.signOut()`, whose failure is only logged. A
  sign-in that landed during the last word stands: `endLocalSession()` answers `false` and `signOut()` skips the pool.
- Expired session (`SessionController.swift:endExpiredSession`): with nobody signed in nothing happens (debug line);
  otherwise, inside `holdingSignOutSlot`, `endLocalSession()`, then `AppError.sessionExpired` is reported unless it is
  already the current popup, then `authService.signOut()` through the shared `signOutOfPool()`, whose failure is only
  logged. A report while a sign-out runs is turned away; one whose session changed hands during the last word stands down.
- `performSignIn`: success sets `state = .signedIn` and nothing else (the name other players see is the backend
  profile's, `lily/Features/Profile/State`, chosen by the user; nothing is derived or synced here);
  `AppError.emailNotConfirmed` returns `.confirmationRequired` with no popup; anything else goes through `report`.
- `report`: a `CancellationError` is logged at info and shown nowhere; `.providerUnavailable` logs at warning, other
  errors at error; the popup receives `AppError.wrapping(error)`, or `fallback` when that is `.unknown`; always `.failed`.
- `confirmSignUp` answers `.confirmedButSignInFailed` when the code was accepted but the sign-in after it did not land
  (that sign-in reported itself, so one popup), `.failed` when the confirmation itself failed
  (`SessionController+EmailConfirmation.swift:confirmSignUp`).
- Observers are held weakly (`SessionController.swift:WeakSessionObserver`); dead entries are dropped on every
  `notifyObservers`. `continueAsGuest()` saves `.guest` before setting `state`.

## Side Effects

- `SessionStore`: `save(.guest)` in `continueAsGuest` and after a guest choice during the restore check; `clear()` in
  `endLocalSession` (`SessionController.swift`).
- `ErrorCenter.report(_:)` from `report(_:during:fallback:)`; `ErrorCenter.report(.sessionExpired)` from `endExpiredSession()`.
- Spawned tasks: `restoreCheck` (in `restore()`).
- Observer callbacks: `sessionWillEnd()` (awaited), `sessionDidEnd()`, `sessionDidRestore()`.
- Network through `authService` (`restoreSession`, `signIn`, `signUp`, `confirmSignUp`, `resendConfirmationCode`,
  `signOut`) only.
- Logging under `.auth`: sign-in started, succeeded (with user id) or needing confirmation, signed out, session
  restored, guest mode, sign-up and confirmation steps (info); session verified (debug); a cached session the pool
  has no session for dropped (warning); `Session expired for user <id>` (warning); busy slots, dropped answers and an
  expiry with nobody signed in (debug); a failed remote sign-out, a refused provider (warning); failed steps (error).
  Ids only, never credentials.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Auth`).
