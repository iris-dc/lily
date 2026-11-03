# Auth Models

Source: `lily/Core/Auth/Models/`

## Overview

Framework-free value types for the session: who is signed in, how they authenticate, what survives a relaunch, and the
outcomes `SessionController` answers to the sign-in form. All are `nonisolated`, `Hashable` and `Sendable`; the persisted
ones are `Codable`. No tokens live here: Cognito's stay in Amplify's keychain.

## Interface

- `AuthUser` (`lily/Core/Auth/Models/AuthUser.swift:AuthUser`): `Codable, Hashable, Identifiable, Sendable`; `id: String`
  (the Cognito `sub`) and `email: String?`, nothing else: the name other players see is the backend profile's
  (`ProfileStore`, `lily/Features/Profile/State`), chosen by the user, never derived from the email.
- `AuthSession` (`lily/Core/Auth/Models/AuthSession.swift:AuthSession`): `Codable` struct wrapping `user: AuthUser`.
- `StoredSession` (`lily/Core/Auth/Models/AuthSession.swift:StoredSession`): `Codable` enum `.guest`,
  `.signedIn(AuthSession)`, `.signingOut`.
- `EmailCredentials` (`lily/Core/Auth/Models/AuthProvider.swift:EmailCredentials`): `email`, `password`.
- `AuthProvider` (`lily/Core/Auth/Models/AuthProvider.swift:AuthProvider`): `.apple`, `.google`, `.email(EmailCredentials)`;
  nested `Kind: String, Sendable` (`apple`, `google`, `email`) with `displayName` (`"Apple"`, `"Google"`,
  `localized("Email")`); `var kind: Kind`.
- `SessionState` (`lily/Core/Auth/Models/SessionState.swift:SessionState`): `.signedOut`, `.guest`, `.signedIn(AuthUser)`;
  `user: AuthUser?`, `isSignedIn: Bool`, `showsShell: Bool`.
- `SignUpOutcome` (`lily/Core/Auth/Models/SignUpOutcome.swift:SignUpOutcome`): `.signedUp`, `.confirmationRequired`.
- `EmailAuthResult` (`lily/Core/Auth/Models/EmailAuthResult.swift:EmailAuthResult`): `.signedIn`, `.confirmationRequired`, `.failed`.
- `ConfirmOutcome` (`lily/Core/Auth/Models/ConfirmOutcome.swift:ConfirmOutcome`): `.signedIn`, `.confirmedButSignInFailed`, `.failed`.

## Invariants

- A session stored before the name moved to the backend profile still carries a `displayName` key, which `AuthUser`'s
  synthesized decoder ignores, so the cached sign-in survives the change (`AuthUser.swift:AuthUser`).
- `SessionState.isSignedIn` is true only for `.signedIn`, the one state that may ask for user-scoped content or write;
  `showsShell` is true for `.guest` and `.signedIn`, false for `.signedOut` (`SessionState.swift:SessionState`).
- `StoredSession.signingOut` marks a sign-out the pool has not confirmed: saved before Amplify is asked, cleared once
  it answered, so a process killed in between finishes the sign-out on the next launch (`AuthSession.swift:StoredSession`).
- `AuthProvider.Kind` is the credential-free identity of a provider, safe to log and display; `EmailCredentials`, which
  holds the password, is not (`AuthProvider.swift:Kind`).
- `EmailAuthResult.confirmationRequired` is not a failure and shows no popup (the form switches to the code step);
  `ConfirmOutcome.confirmedButSignInFailed` means the pool accepted the code and only the sign-in after it failed, so a
  second confirm (refused by Cognito as not authorized) is never offered (`EmailAuthResult.swift`, `ConfirmOutcome.swift`;
  enforced in [the parent](../EGM.md)).

## Side Effects

- `AuthProvider.Kind.displayName` reads copy through `localized(_:)` (`lily/Core/Localization/Localized.swift`). No other I/O.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Auth`).
