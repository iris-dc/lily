# Moderation: Views

Source: `lily/Features/Moderation/Views/`

## Overview

The terms sheet the root presents while `TermsViewModel.isPresented` holds: a title and message that scroll, three legal
links in a wrapping row, a prominent "I agree" button and a text-only "Sign out" under it, the text actions in ink
through `lilyTextButton`. It cannot be swiped away and
mounts its own `.errorPopup` because a sheet draws above the root's.

Files: `lily/Features/Moderation/Views/TermsSheet.swift`.

## Interface

- `[TermsSheet.swift:TermsSheet]`: `struct TermsSheet: View` with `let viewModel: TermsViewModel`, `let errorCenter:
  ErrorCenter`. Body: `ContentScreen` holding a `VStack` of a `ScrollView` (`ScreenTitle(text:
  AppBranding.Moderation.termsTitle)`, `Text(AppBranding.Moderation.termsMessage)`, `legalLinks`), `acceptButton` and
  `signOutButton`, padded `DesignTokens.Spacing.xl` under `.readableColumn()`, then `.lilyFormSheet()`,
  `.interactiveDismissDisabled()`, `.errorPopup(errorCenter)`.
- `[TermsSheet.swift:TermsSheet.legalLinks]`: a `FlowLayout(spacing: DesignTokens.Spacing.lg, rowSpacing: 0)` of
  `legalLink(_:to:)` for `AppBranding.Moderation.termsLink` → `AppConfig.Moderation.termsURL`, `.privacyLink` →
  `.privacyURL`, `.supportLink` → `.supportURL` (the private `Links` alias); each a `Link(_:destination:)` under
  `lilyTextButton(font: .subheadline)` (`lily/Core/UI/Components/ButtonModifiers.swift`), which supplies the 44pt label.
- `[TermsSheet.swift:TermsSheet.acceptButton]`: `lilyProminentButton()` labelled `AppBranding.Moderation.accept`, a
  small `ProgressView` with `.accessibilityLabel(Copy.accept)` while `viewModel.isAccepting`;
  `AccessibilityIdentifiers.termsAccept`.
- `[TermsSheet.swift:TermsSheet.signOutButton]`: a full-width text button `AppBranding.signOutAction` under
  `lilyTextButton()` (the button font, ink, the 44pt label); `AccessibilityIdentifiers.termsSignOut`.

## Invariants

- `[TermsSheet.swift:TermsSheet.body]`: `.interactiveDismissDisabled()`: agreeing or signing out are the only ways out
  (on iPad a tap beside the form sheet does not dismiss it either); the root decides presentation from
  `TermsViewModel.isPresented`.
- `[TermsSheet.swift:TermsSheet.acceptButton]`, `[TermsSheet.swift:TermsSheet.signOutButton]`: both are
  `.disabled(viewModel.isAccepting)`, so neither action can start while an acceptance is in flight; VoiceOver keeps
  reading "I agree" on the spinner.
- `[TermsSheet.swift:TermsSheet.body]`: the copy scrolls (`.scrollBounceBehavior(.basedOnSize)`) while the two buttons
  stay below it, so accessibility sizes read the message whole.
- `[TermsSheet.swift:TermsSheet.legalLinks]`: the URLs come from `AppConfig.Moderation`, never typed inline.

## Side Effects

- `[TermsSheet.swift:TermsSheet.acceptButton]`: spawns `Task { await viewModel.accept() }` (the backend write through
  `MeStore`).
- `[TermsSheet.swift:TermsSheet.signOutButton]`: spawns `Task { await viewModel.signOut() }` (logs and signs out).
- `[TermsSheet.swift:TermsSheet.legalLink]`: `Link(destination:)` opens the terms, privacy or support URL outside the
  app.
- `[TermsSheet.swift:TermsSheet.body]`: `.errorPopup(errorCenter)` mounts the shared error popup on the sheet.
- No logging, disk or `UserDefaults` access is made directly by this view.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the view model behind this sheet is pinned in
  `lilyTests/Moderation/TermsViewModelTests.swift`; the sheet is exercised by the UI tests, `./scripts/ci.sh ui`).
