# Moderation: Views

Source: `lily/Features/Moderation/Views/`

## Overview

The terms sheet the root presents while `TermsViewModel.isPresented` holds: a title and message that scroll, three legal
links in a wrapping row, a prominent "I agree" button, a text-only "Sign out" under it and a red "Delete account" last
(the terms-pending way into the delete flow, 2026-11-07: the non-dismissable sheet covers the shell, so deletion must be
reachable from here — the relocation contract's session-state matrix), the text actions through `lilyTextButton`. It
cannot be swiped away and mounts its own `.errorPopup` because a sheet draws above the root's.

Files: `lily/Features/Moderation/Views/TermsSheet.swift`.

## Interface

- `[TermsSheet.swift:TermsSheet]`: `struct TermsSheet: View` with `let viewModel: TermsViewModel`, `let dependencies:
  AppDependencies` (2026-11-07; the error center is read from it, and `makeDeleteAccountViewModel()` builds the delete
  flow). Body: `ContentScreen` holding a `VStack` of a `ScrollView` (`ScreenTitle(text:
  AppBranding.Moderation.termsTitle)`, `Text(AppBranding.Moderation.termsMessage)`, `legalLinks`), `acceptButton`,
  `signOutButton` and `deleteAccountButton`, padded `DesignTokens.Spacing.xl` under `.readableColumn()`, then
  `.lilyFormSheet()`, `.interactiveDismissDisabled()`, `.errorPopup(errorCenter)` and a `.sheet(isPresented:
  $isDeletePresented)` presenting `DeleteAccountSheet(viewModel: dependencies.makeDeleteAccountViewModel(),
  errorCenter:)`.
- `[TermsSheet.swift:TermsSheet.legalLinks]`: a `FlowLayout(spacing: DesignTokens.Spacing.lg, rowSpacing: 0)` of
  `legalLink(_:to:)` for `AppBranding.Moderation.termsLink` → `AppConfig.Moderation.termsURL`, `.privacyLink` →
  `.privacyURL`, `.supportLink` → `.supportURL` (the private `Links` alias); each a `Link(_:destination:)` under
  `lilyTextButton(font: .subheadline)` (`lily/Core/UI/Components/ButtonModifiers.swift`), which supplies the 44pt label.
- `[TermsSheet.swift:TermsSheet.acceptButton]`: `lilyProminentButton()` labelled `AppBranding.Moderation.accept`, a
  small `ProgressView` with `.accessibilityLabel(Copy.accept)` while `viewModel.isAccepting`;
  `AccessibilityIdentifiers.termsAccept`.
- `[TermsSheet.swift:TermsSheet.signOutButton]`: a full-width text button `AppBranding.signOutAction` under
  `lilyTextButton()` (the button font, ink, the 44pt label); `AccessibilityIdentifiers.termsSignOut`.
- `[TermsSheet.swift:TermsSheet.deleteAccountButton]` (2026-11-07): a full-width text button
  `AppBranding.DeleteAccount.title` under `lilyTextButton(color: .red)` — red so it never reads as a third way to
  agree; `AccessibilityIdentifiers.termsDeleteAccount`; sets `isDeletePresented`, so the delete flow presents over the
  terms sheet with the same pinned teardown order as the Settings path (the relocation contract §4).

## Invariants

- `[TermsSheet.swift:TermsSheet.body]`: `.interactiveDismissDisabled()`: agreeing or signing out are the only ways out
  (on iPad a tap beside the form sheet does not dismiss it either); the root decides presentation from
  `TermsViewModel.isPresented`.
- `[TermsSheet.swift:TermsSheet.acceptButton]`, `[TermsSheet.swift:TermsSheet.signOutButton]`,
  `[TermsSheet.swift:TermsSheet.deleteAccountButton]`: all three are `.disabled(viewModel.isAccepting)`, so no second
  action can start while an acceptance is in flight; VoiceOver keeps reading "I agree" on the spinner.
- `[TermsSheet.swift:TermsSheet.body]`: the copy scrolls (`.scrollBounceBehavior(.basedOnSize)`) while the two buttons
  stay below it, so accessibility sizes read the message whole.
- `[TermsSheet.swift:TermsSheet.legalLinks]`: the URLs come from `AppConfig.Moderation`, never typed inline.

## Side Effects

- `[TermsSheet.swift:TermsSheet.acceptButton]`: spawns `Task { await viewModel.accept() }` (the backend write through
  `MeStore`).
- `[TermsSheet.swift:TermsSheet.signOutButton]`: spawns `Task { await viewModel.signOut() }` (logs and signs out).
- `[TermsSheet.swift:TermsSheet.legalLink]`: `Link(destination:)` opens the terms, privacy or support URL outside the
  app.
- `[TermsSheet.swift:TermsSheet.deleteAccountButton]`: presents `DeleteAccountSheet` (its network, session and popup
  effects live behind `DeleteAccountViewModel`, `../../Profile/ViewModels/EGM.md`); only that flow's acknowledge tap
  ends the session, which then drops this sheet too (the identity is gone, so `TermsViewModel.isPresented` turns false).
- `[TermsSheet.swift:TermsSheet.body]`: `.errorPopup(errorCenter)` mounts the shared error popup on the sheet.
- No logging, disk or `UserDefaults` access is made directly by this view.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the view model behind this sheet is pinned in
  `lilyTests/Moderation/TermsViewModelTests.swift`; the sheet is exercised by the UI tests, `./scripts/ci.sh ui`).
