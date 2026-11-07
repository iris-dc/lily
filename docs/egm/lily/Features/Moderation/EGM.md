# Moderation

Source: `lily/Features/Moderation/`

## Overview

The terms-acceptance gate: a sheet the root presents while a signed-in caller owes the current terms (`MeStore.needsTerms`
with a current user id), closed only by an acceptance the backend recorded or by signing out. The feature has no direct
source files: `ViewModels` holds `TermsViewModel`, `Views` holds `TermsSheet`. The acceptance write, its error popup and
its success log live in `MeStore` (`lily/Features/Groups/State/MeStore.swift`); the legal URLs are
`AppConfig.Moderation.termsURL`, `privacyURL` and `supportURL`. (Reporting other users and the block list live in
`lily/Features/Groups`, as `ReportViewModel`, `ReportSheet`, the `Report.swift` models (`ReportReason`,
`ReportTarget`, `ReportPayload`, `ReportReceipt`) and `BlockListStore`, reached from the chat transcript, the group
detail and the tournament detail; they are not part of this directory.)

## Subdirectories & Boundaries

- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `TermsViewModel` (`@Observable`): `isPresented` =
  `identity.currentUserID != nil && me.needsTerms`, the three URLs from `AppConfig.Moderation`, `accept()` (guarded by
  `isAccepting`, awaits `me.acceptTerms()` and discards the result), `signOut()` (logs `.groups` info "Terms declined:
  signing out" and runs the injected sign-out).
- Views: [./Views/EGM.md](./Views/EGM.md) - `TermsSheet` (`viewModel`, `dependencies: AppDependencies` since
  2026-11-07): scrolling title and message from `AppBranding.Moderation`, a `FlowLayout` of three `Link`s, the
  prominent accept button (`AccessibilityIdentifiers.termsAccept`, spinner while accepting), the text sign-out button
  (`AccessibilityIdentifiers.termsSignOut`) and the red delete-account entry (`termsDeleteAccount`, presenting
  `DeleteAccountSheet` — the terms-pending way into deletion), all disabled while accepting; `.lilyFormSheet()`,
  `.interactiveDismissDisabled()`, its own `.errorPopup`.
