# Auth Implementations

Source: `lily/Core/Auth/Implementations/`

## Overview

The concrete types behind the Auth interfaces. `AmplifyCognitoClient` is the only file in the app that sees Amplify's
types; `CognitoAuthService` turns the pool's answers into `AppError`s and keeps the signed-in user in the `SessionStore`;
`UserDefaultsSessionStore` is that store; `MockAuthService` stands in for Cognito in previews, UI tests and the
simulator; `SessionIdentityProvider` answers who the app acts for; `JWTClaims` reads `exp` off a token;
`AmplifyConfigurationBuilder` builds the plug-in JSON from `AppConfig.Cognito` instead of a generated
`amplifyconfiguration.json`. The classes are main-actor isolated by the target's default; the enums are `nonisolated`.

## Interface

- `AmplifyCognitoClient: CognitoClient` (`lily/Core/Auth/Implementations/AmplifyCognitoClient.swift:AmplifyCognitoClient`):
  `init(logger: any Logging)`; every protocol member first awaits `ready()` (one shared static `Task` that adds
  `AWSCognitoAuthPlugin` and calls `Amplify.configure`), then runs the Amplify call inside `mapped` (every member but
  `signOut()`, which maps only a `.failed` result through `CognitoClientError`), which rethrows as
  `CognitoClientError`. `freshAccessToken()` passes `AuthFetchSessionRequest.Options(forceRefresh: true)`.
- `AmplifyConfigurationBuilder` (`lily/Core/Auth/Implementations/AmplifyConfigurationBuilder.swift:AmplifyConfigurationBuilder`):
  `pluginKey = "awsCognitoAuthPlugin"`, `authenticationFlow = "USER_SRP_AUTH"`,
  `cognitoPluginJSON(userPoolId:appClientId:region:) throws -> Data` (defaults from `AppConfig.Cognito`; keys
  `CognitoUserPool.Default` and `Auth.Default.authenticationFlowType`, sorted).
- `CognitoAuthService: AuthService, AuthTokenProvider, SessionExpiryReporter` (`lily/Core/Auth/Implementations/CognitoAuthService.swift:CognitoAuthService`):
  `init(client: any CognitoClient, store: any SessionStore, languageCode: @escaping () -> String = { AppLanguage.systemChoice().code }, logger: any Logging)`;
  `var onSessionExpired: () -> Void = {}`.
- `JWTClaims` (`lily/Core/Auth/Implementations/JWTClaims.swift:JWTClaims`): `static expiration(of token: String) -> Date?`
  (second segment base64url-decoded, its `exp` claim; `nil` when the token is not a JWT with one).
- `MockAuthBehavior` (`lily/Core/Auth/Implementations/MockAuthService.swift:MockAuthBehavior`): `.succeed`, `.fail(AppError)`,
  `.requireConfirmation(code: String)`. `MockAuthService: AuthService` (`MockAuthService.swift:MockAuthService`):
  `init(behavior: MockAuthBehavior = .succeed, delay: Duration = AppConfig.Auth.mockSignInDelay, store: any SessionStore, userIDOverride: String? = nil, sleep: @escaping Sleep = systemSleep)`.
  `MockUsers` (`MockAuthService.swift:MockUsers`): `user(for: AuthProvider) -> AuthUser`, `user(withID:) -> AuthUser`.
- `SessionIdentityProvider: IdentityProvider` (`lily/Core/Auth/Implementations/SessionIdentityProvider.swift:SessionIdentityProvider`):
  `weak var session: SessionController?`; `currentUserID` is `session?.state.user?.id` (linked by the composition root
  after the API client is built).
- `UserDefaultsSessionStore: SessionStore` (`lily/Core/Auth/Implementations/UserDefaultsSessionStore.swift:UserDefaultsSessionStore`):
  `init(defaults: UserDefaults = .standard, logger: any Logging)`; JSON-encodes `StoredSession` under
  `AppConfig.Storage.Keys.storedSession`.

## Invariants

- Amplify is configured once per process: `AmplifyCognitoClient.ready()` creates the static `configuring` task on the
  first call, never at construction (the composition root builds the client in unit tests too, where nothing may reach
  Amplify); a configuration failure surfaces as `CognitoClientError.other("Amplify configuration failed: ...")`.
- `AmplifyCognitoClient.signIn` signs a stale Amplify session out first (Amplify answers `invalidState` otherwise);
  `step(of:)` puts only the case name of an unhandled `AuthSignInStep` into `.otherStep`, never its associated values
  (the code's delivery destination). `signOut()` throws only on `.failed`; `.partial` is accepted and logged.
- `CognitoClientError.init(_:)` (`AmplifyCognitoClient.swift`): `AuthError.notAuthorized` to `.notAuthorized`;
  `.sessionExpired` and `.signedOut` to `.sessionExpired`; a `URLError` anywhere to `.network`; `AWSCognitoAuthError`
  `userNotFound`, `userNotConfirmed`, `usernameExists`/`aliasExists`, `invalidPassword`, `codeMismatch`, `codeExpired`,
  `limitExceeded`, `limitExceededException`, `requestLimitExceeded` and `failedAttemptsLimitExceeded` (all four to
  `limitExceeded`) and `network` to their namesakes; everything else `.other(description)` (an
  `AuthError` carries its `errorDescription`, any other error its type name).
- `CognitoAuthService.restoreSession()` in order: no pool session drops a cached `.signedIn` or `.signingOut` (a `.guest`
  stands) and returns `nil`; a `.signingOut` marker or a `.guest` beside a pool session signs the pool out and returns
  `nil`; a token check failing with `AppError.sessionExpired` clears a cached `.signedIn`, signs the pool out and returns
  `nil`, while any other failure (offline) keeps the session for the backend's 401 to decide; then a cached `.signedIn`
  is returned without a round trip, a `.signingOut` found after the token check answers `nil` (the sign-out in flight
  owns the marker), and the user is loaded and cached only over an empty store or a guest choice.
- `CognitoAuthService.signIn(with:)` throws `AppError.providerUnavailable(provider:)` for `.apple` and `.google`,
  `AppError.emailNotConfirmed` on `.confirmationRequired`, `AppError.authFailed(provider: .email)` on `.otherStep`.
  `loadAndCacheSession` signs the pool out again when the user cannot be read, so pool and app never disagree.
- `CognitoAuthService.signOut()` saves `.signingOut` before asking the client and clears the marker only when it is
  still there afterwards: a guest choice or a new sign-in stored meanwhile stands.
- `CognitoAuthService.token(_:_:)` (behind `accessToken()` and `freshAccessToken()`) never throws; a fetch failing with
  `CognitoClientError.sessionExpired` fires `onSessionExpired` once per run of such failures and a fetch that returns
  (a token or `nil`) arms it again; `.network`, `.other` and a `nil` answer never fire it.
- `CognitoAuthService.mapped` logs an `.other(description)` at warning before rethrowing it as `AppError`; `token(_:_:)`
  stays outside `mapped`, so a token failure is logged once.
- `CognitoClientError.appError` (`CognitoAuthService.swift`): `.notAuthorized`, `.userNotFound`, `.invalidPassword` to
  `.invalidCredentials`; `.userNotConfirmed` to `.emailNotConfirmed`; `.usernameExists` to `.emailTaken`;
  `.codeMismatch`, `.codeExpired` to `.invalidConfirmationCode`; `.limitExceeded` to `.tooManyAttempts`; `.network`
  and `.sessionExpired` unchanged; `.other` to `.authFailed(provider: .email)`.
- `MockAuthService`: `signUp` throws `AppError.invalidCredentials` unless `CredentialsValidator` (`lily/Core/Validation`)
  accepts both fields; `.requireConfirmation(code:)` makes sign-up answer `.confirmationRequired` and `confirmSignUp`
  throw `AppError.invalidConfirmationCode` for any other code; `.fail(error)` throws after the simulated delay.
  `MockUsers.opaqueID` is a SHA-256 prefix of the lower-cased email, so a user id never embeds the address.
- `UserDefaultsSessionStore.load()` removes a value that no longer decodes and returns `nil`. `JWTClaims` does not
  verify the token: the backend and AppSync do.

## Side Effects

- Network: `Amplify.Auth.fetchAuthSession`, `getCurrentUser`, `fetchUserAttributes`, `signIn`, `signUp` (with
  `AuthUserAttribute(.email)` and client metadata `[AppConfig.Cognito.localeMetadataKey: languageCode]`),
  `confirmSignUp`, `resendSignUpCode`, `signOut` (`AmplifyCognitoClient.swift`); Amplify keeps the tokens in its keychain.
- Process-wide: `Amplify.add(plugin:)` and `Amplify.configure(...)` once (`AmplifyCognitoClient.configure`).
- UserDefaults: `UserDefaultsSessionStore` sets and removes `AppConfig.Storage.Keys.storedSession`;
  `CognitoAuthService` saves `.signedIn` and `.signingOut` and clears through it; `MockAuthService` saves `.signedIn` on
  sign-in and clears on sign-out.
- Logging under `.auth` (`AmplifyCognitoClient.swift`, `CognitoAuthService.swift`): info for a stale-session sign-out and
  each restore decision (dropped cache, finished sign-out, guest choice ending a pool session, kept session); warning for
  a locally-only sign-out, an unsupported sign-in step, a missing token, an expired refresh token, a failed user load or
  compensating sign-out, `Cognito call failed: <description>` for an `.other` client error; info for a `.signingOut`
  marker found after the token check (`its marker stands`). `onSessionExpired` is called from `token(_:_:)`. Under `.cache` (`UserDefaultsSessionStore.swift`): debug hit, miss and invalidated; warning for
  an unreadable value; error for a failed encode.
- Timers: `MockAuthService.simulateNetwork` awaits the injected `Sleep` for `delay` when it is above zero.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Auth`).
