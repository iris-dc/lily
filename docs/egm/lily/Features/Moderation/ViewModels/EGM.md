# Moderation: ViewModels

Source: `lily/Features/Moderation/ViewModels/`

## Overview

The terms sheet's state: whether a signed-in caller owes the current terms, the three legal URLs, and the two ways out
(accept, which `MeStore` records with the backend, or sign out through an injected closure). The view model brackets the
in-flight acceptance only; reporting and the success log belong to `MeStore`. Main-actor isolated by the app target's
default; depends on `MeStore`, `any IdentityProvider` and `any Logging`.

Files: `lily/Features/Moderation/ViewModels/TermsViewModel.swift`.

## Interface

- `[TermsViewModel.swift:TermsViewModel]`: `@Observable final class TermsViewModel`; `private(set) var isAccepting =
  false`; `init(me: MeStore, identity: any IdentityProvider, logger: any Logging, signOut: @escaping () async -> Void)`.
- `[TermsViewModel.swift:TermsViewModel.isPresented]`: `var isPresented: Bool` = `identity.currentUserID != nil &&
  me.needsTerms`.
- `[TermsViewModel.swift:TermsViewModel.termsURL]`: `var termsURL: URL`, `var privacyURL: URL`, `var supportURL: URL`
  read `AppConfig.Moderation.termsURL`, `.privacyURL`, `.supportURL`.
- `[TermsViewModel.swift:TermsViewModel.accept]`: `func accept() async` awaits `me.acceptTerms()` while `isAccepting`.
- `[TermsViewModel.swift:TermsViewModel.signOut]`: `func signOut() async` logs and runs the injected sign-out.

## Invariants

- `[TermsViewModel.swift:TermsViewModel.isPresented]`: a guest is never asked: presentation requires a current user id
  as well as `me.needsTerms` (the comment notes `MeStore.termsOutdated` can be set without an account).
- `[TermsViewModel.swift:TermsViewModel.accept]`: `guard !isAccepting else { return }`, so a second tap during the
  request is ignored; `isAccepting` is set before the await and reset by `defer`; the result of `me.acceptTerms()` is
  discarded (`_ =`) because `MeStore` reports a failure to the popup and logs a success itself.
- `[TermsViewModel.swift:TermsViewModel.signOut]`: the view model clears nothing itself; the session's observers clear
  the account and `isPresented` follows.
- `[TermsViewModel.swift:TermsViewModel]`: `isAccepting` is `private(set)`; the URLs are read from `AppConfig`, never
  typed inline.

## Side Effects

- Network: `[TermsViewModel.swift:TermsViewModel.accept]` calls `me.acceptTerms()`, the backend write that records the
  acceptance.
- Logging: `[TermsViewModel.swift:TermsViewModel.signOut]` logs `.groups` info `"Terms declined: signing out"`.
- Session: `[TermsViewModel.swift:TermsViewModel.signOut]` awaits the injected `signOutAction()`, the app's sign-out.
- No tasks are spawned here, nothing is written to disk or `UserDefaults`.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suite is
  `lilyTests/Moderation/TermsViewModelTests.swift`).
