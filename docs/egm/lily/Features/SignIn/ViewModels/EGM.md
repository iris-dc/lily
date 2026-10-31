# SignIn: ViewModels

Source: `lily/Features/SignIn/ViewModels/`

## Overview

Two observable view models for the sign-in sheet. `SignInViewModel` drives the provider buttons and the push into the
email form, owning the in-flight provider sign-in so a dismissed sheet can cancel it. `EmailSignInViewModel` holds the
email, password and code fields and the three-step mode (sign in, sign up, confirm), validates them, and submits through
the `SessionController`. Neither reports errors or logs: the session does both. Both are main-actor isolated by the app
target's default; `EmailAuthMode` is `nonisolated` data.

Files: `lily/Features/SignIn/ViewModels/SignInViewModel.swift`,
`lily/Features/SignIn/ViewModels/EmailSignInViewModel.swift`.

## Interface

- `[SignInViewModel.swift:SignInViewModel]`: `@Observable final class SignInViewModel`; `var isEmailFormPresented =
  false`; `private(set) var signInTask: Task<Void, Never>?`; `init(session: SessionController)`;
  `var authenticatingProvider: AuthProvider.Kind?` = `session.authenticatingProvider`; `var isBusy: Bool` =
  `authenticatingProvider != nil`; `func signInWithApple()`, `func signInWithGoogle()`, `func presentEmailForm()`,
  `func cancel()`; `private func signIn(with provider: AuthProvider)`.
- `[EmailSignInViewModel.swift:EmailAuthMode]`: `nonisolated enum EmailAuthMode: Hashable, Sendable` with cases
  `signIn`, `signUp`, `confirm`; `var title: String` (`AppBranding.signInSheetTitle` / `signUpSheetTitle` /
  `confirmEmailTitle`), `var submitLabel: String` (`AppBranding.signInAction` / `signUpAction` / `confirmAction`),
  `var toggleLabel: String` (`AppBranding.signUpPrompt` / `signInPrompt` / `backToSignInAction`), `var toggled:
  EmailAuthMode` = `self == .signIn ? .signUp : .signIn`.
- `[EmailSignInViewModel.swift:EmailSignInViewModel]`: `@Observable final class EmailSignInViewModel`; `var email`,
  `var password`, `var code: String` (all `""`); `var mode: EmailAuthMode = .signIn`; `private(set) var isSubmitting`,
  `private(set) var isResending: Bool`; `private(set) var submitTask: Task<Void, Never>?`; `init(session:
  SessionController)`.
- `[EmailSignInViewModel.swift:EmailSignInViewModel.canSubmit]`: `var isBusy: Bool` = `isSubmitting || isResending`;
  `var canSubmit: Bool`; `var subtitle: String` (`AppBranding.confirmEmailSubtitle(email:)` in confirm, else
  `AppBranding.emailSignInSubtitle`); `var passwordHint: String` = `AppBranding.passwordHint(minimumLength:
  AppConfig.Auth.minimumPasswordLength)`.
- `[EmailSignInViewModel.swift:EmailSignInViewModel.submit]`: `func toggleMode()`, `func submit()`, `func resendCode()`,
  `func cancel()`; private `returnToSignIn()`, `trimmedEmail`, `isCodeComplete`, `authenticate() async`,
  `enterConfirmationIfNeeded(_ result: EmailAuthResult)`.

## Invariants

- `[SignInViewModel.swift:SignInViewModel.signIn(with:)]`: a new provider sign-in cancels the previous `signInTask`
  before starting; `cancel()` cancels and clears it, so nothing finishes signing in after the sheet is gone.
- `[SignInViewModel.swift:SignInViewModel.isBusy]`: busy state is read from the session
  (`session.authenticatingProvider`), not kept locally.
- `[EmailSignInViewModel.swift:EmailSignInViewModel.canSubmit]`: `false` while `isBusy`; in `.signIn` and `.signUp` it
  requires `CredentialsValidator.isValidEmail(email) && CredentialsValidator.isValidPassword(password)`; in `.confirm`
  it requires `isCodeComplete`, i.e. `code.count == AppConfig.Cognito.confirmationCodeLength && code.allSatisfy(\.isNumber)`.
- `[EmailSignInViewModel.swift:EmailSignInViewModel.submit]`: `guard canSubmit else { return }` (the keyboard's return
  key can reach it with the button disabled); `isSubmitting` is set before the task and reset by `defer` inside it.
- `[EmailSignInViewModel.swift:EmailSignInViewModel.resendCode]`: `guard !isBusy, mode == .confirm else { return }`;
  `isResending` bracketed the same way.
- `[EmailSignInViewModel.swift:EmailSignInViewModel.authenticate]`: the email is sent trimmed (`email.trimmed`), the
  password as typed; `.signIn` → `session.signIn(withEmail: EmailCredentials)`, `.signUp` → `session.signUp(email:
  password:)`, both moving to `.confirm` on `EmailAuthResult.confirmationRequired`; `.confirm` →
  `session.confirmSignUp(email:code:password:)`, returning to `.signIn` (code cleared, email and password kept) on
  `.confirmedButSignInFailed`.
- `[EmailSignInViewModel.swift:EmailSignInViewModel.toggleMode]`: always clears `code`; from `.confirm` the toggle goes
  back to `.signIn` (`toggled`), never to `.signUp`.
- `[EmailSignInViewModel.swift:EmailAuthMode]`: `nonisolated` and `Sendable`; the view models' mutable state is
  main-actor only.

## Side Effects

- `[SignInViewModel.swift:SignInViewModel.signIn(with:)]`: spawns `Task { await session.signIn(with: provider) }` and
  keeps it in `signInTask`.
- `[EmailSignInViewModel.swift:EmailSignInViewModel.submit]`, `[EmailSignInViewModel.swift:EmailSignInViewModel.resendCode]`:
  spawn a `Task` kept in `submitTask` that calls `session.signIn(withEmail:)`, `session.signUp(email:password:)`,
  `session.confirmSignUp(email:code:password:)` or `session.resendConfirmationCode(email:)` (Cognito through the
  session).
- No logging, disk, `UserDefaults` or direct `ErrorCenter` calls; the session reports failures to the popup.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites are
  `lilyTests/SignIn/SignInViewModelsTests.swift` and `lilyTests/SignIn/EmailSignInViewModelConfirmReturnTests.swift`).
