# Auth Interfaces

Source: `lily/Core/Auth/Interfaces/`

## Overview

The protocols and framework-free value types that `SessionController` (the parent directory) and the rest of the app
depend on for authentication, so `CognitoAuthService` and `MockAuthService` are interchangeable and nothing outside
`Implementations/` imports Amplify. `CognitoClient` is the thin seam over Amplify; `AuthService` is the app-facing
boundary; `AuthTokenProvider`, `SessionExpiryReporter`, `IdentityProvider`, `SessionObserver` and `SessionStore` are the
small roles other layers read the session through. The protocols are main-actor isolated by the target's default; the value types are
`nonisolated` and `Sendable`.

## Interface

- `AuthService` (`lily/Core/Auth/Interfaces/AuthService.swift:AuthService`): `restoreSession() async throws -> AuthSession?`,
  `signIn(with: AuthProvider) async throws -> AuthSession`, `signUp(email:password:) async throws -> SignUpOutcome`,
  `confirmSignUp(email:code:) async throws`, `resendConfirmationCode(email:) async throws`, `signOut() async throws`.
- `AuthTokenProvider` (`lily/Core/Auth/Interfaces/AuthTokenProvider.swift:AuthTokenProvider`): `accessToken() async -> String?`
  (the REST client's token, `nil` for a guest or when none can be produced) and `freshAccessToken() async -> String?`
  (refreshed at the pool even when still valid; the realtime connection only).
- `CognitoClient` (`lily/Core/Auth/Interfaces/CognitoClient.swift:CognitoClient`): `isSignedIn()`, `accessToken()`,
  `freshAccessToken()`, `currentUser() -> CognitoUser`, `fetchEmail() -> String?`,
  `signIn(username:password:) -> CognitoSignInStep`, `signUp(email:password:languageCode:) -> CognitoSignUpStep`,
  `confirmSignUp(email:code:)`, `resendCode(email:languageCode:)`, `signOut()`; all `async throws`.
- `CognitoUser` (`lily/Core/Auth/Interfaces/CognitoClient.swift:CognitoUser`): `nonisolated struct` with `sub` (the id the
  backend reads from the token) and `username` (the pool's own name, a UUID when the pool signs in by email alias).
- `CognitoSignInStep` (`lily/Core/Auth/Interfaces/CognitoClient.swift:CognitoSignInStep`): `.done`, `.confirmationRequired`,
  `.otherStep(String)` (a challenge the app does not handle, named for the log). `CognitoSignUpStep`
  (`CognitoClient.swift:CognitoSignUpStep`): `.done`, `.confirmationRequired`.
- `CognitoClientError` (`lily/Core/Auth/Interfaces/CognitoClient.swift:CognitoClientError`): `nonisolated enum: Error, Hashable,
  Sendable` with `.notAuthorized`, `.userNotFound`, `.userNotConfirmed`, `.usernameExists`, `.invalidPassword`,
  `.codeMismatch`, `.codeExpired`, `.limitExceeded`, `.network`, `.sessionExpired`, `.other(String)`.
- `IdentityProvider` (`lily/Core/Auth/Interfaces/IdentityProvider.swift:IdentityProvider`): `var currentUserID: String? { get }`
  (the Cognito `sub`, `nil` for guests); extension `isStillCaller(_ userID: String, orDrop what: String, logger: any Logging) -> Bool`.
- `SessionExpiryReporter` (`lily/Core/Auth/Interfaces/SessionExpiryReporter.swift:SessionExpiryReporter`): `AnyObject`
  protocol with `var onSessionExpired: () -> Void { get set }`.
- `SessionObserver` (`lily/Core/Auth/Interfaces/SessionObserver.swift:SessionObserver`): `AnyObject` protocol with
  `sessionWillEnd() async`, `sessionWillEndWithoutNetwork() async` (the account-deleted end: the backend's deletion
  job erased everything server-side and the tokens are dead, so an observer does only the local part of its last
  word), `sessionDidEnd()`, `sessionDidRestore()`; the extension gives `sessionWillEnd` and `sessionDidRestore` empty
  defaults and forwards `sessionWillEndWithoutNetwork` to `sessionWillEnd` (right for an observer whose last word
  never touches the network; the network observers, `PushCoordinator` and `RemoteInteractionRecorder`, override it),
  so `sessionDidEnd` is the one member a conformer must write.
- `AccountDeletionSession` (`lily/Core/Auth/Interfaces/AccountDeletionSession.swift:AccountDeletionSession`):
  `AnyObject` protocol with `beginAccountDeletion()`, `cancelAccountDeletion()`, `endDeletedSession() async` — the
  session side of the delete-account flow (2026-11-07), implemented by `SessionController` in `+AccountDeletion`;
  `DeleteAccountViewModel` depends on it, never on the concrete controller. `endDeletedSession()` is called only by
  the acknowledgment's tap (the relocation contract's teardown order); `begin`/`cancel` bracket the flow.
- `SessionStore` (`lily/Core/Auth/Interfaces/SessionStore.swift:SessionStore`): `load() -> StoredSession?`,
  `save(_ session: StoredSession)`, `clear()`.
- The model types in these signatures (`AuthSession`, `StoredSession`, `AuthProvider`, `SignUpOutcome`) are described in
  [Models](../Models/EGM.md); the conformers in [Implementations](../Implementations/EGM.md).

## Invariants

- `AuthService.signIn(with:)` throws `AppError.emailNotConfirmed` for an account whose email was never confirmed, so the
  form can offer the code step (`AuthService.swift:AuthService`, the protocol's stated requirement).
- `AuthTokenProvider.accessToken()` never throws: without a token the request goes out bare and the backend's 401
  becomes `AppError.sessionExpired`; `freshAccessToken()` is for the realtime connection only, the REST client keeps
  `accessToken()`, which refreshes only an expired token (`AuthTokenProvider.swift:AuthTokenProvider`).
- `SessionExpiryReporter.onSessionExpired` is fired once per lost session, when the pool refused to refresh the token;
  the composition root decides what ends (`SessionExpiryReporter.swift:SessionExpiryReporter`).
- `IdentityProvider.isStillCaller` returns `false` once `currentUserID` differs from the id an answer was requested for:
  after a sign-out or a switch the answer belongs to whoever asked (`IdentityProvider.swift:isStillCaller`).
- `SessionObserver.sessionWillEnd()` runs while the user is still signed in, for a last request on their behalf;
  `sessionWillEndWithoutNetwork()` likewise, but on the account-deleted end, where nothing may go out on the dead
  account's behalf; `sessionDidEnd()` after the state ended; `sessionDidRestore()` in the same turn as the state
  change, so nothing renders the state without it (`SessionObserver.swift:SessionObserver`).
- `SessionStore` is a hint, never the source of truth (`SessionStore.swift:SessionStore`); `CognitoClientError` carries
  none of Amplify's types, so the service and its tests never import them (`CognitoClient.swift:CognitoClientError`).

## Side Effects

- `IdentityProvider.isStillCaller` logs `"<what> for a previous caller dropped"` at debug under `.cache`
  (`IdentityProvider.swift:isStillCaller`). The protocols themselves perform no I/O.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Auth`).
