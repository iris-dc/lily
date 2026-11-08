# Profile

Source: `lily/Features/Profile/`

## Overview

The profile sheet (presented from the shell's corner button since 2026-11-07, the relocation contract; a tab before)
and the caller's backend profile. The sheet shows the signed-in user (the name other players see and the
bio under it, each with the card that edits it, and the account's email) with a link row into Settings (the language
and currency dropdown cards, the contact card, the privacy policy read in place (2026-11-08, owner correction), the
terms link, Sign out and Delete account), or the guest prompt with
Sign in and the language, currency and contact rows inline (a guest has no Settings screen; 2026-11-07). The display name and the bio are what the
backend shows to others and the user writes them here: every profile starts as the backend's default name ("Player",
`AppConfig.DisplayName.backendDefault`) with no bio until a write through `PUT /api/profile` (the name or the bio, one
field per request); nothing is derived from the email, since identity stays with Cognito. No source files live at this
level; the six subdirectories below hold them.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `ProfileRepository` with `profile()` (`GET /api/profile`),
  `updateDisplayName(_:)` and `updateBio(_:)` (`PUT /api/profile`, one field each); `ProfileFieldDraft`, what the two
  editors' drafts share.
- Models: [./Models/EGM.md](./Models/EGM.md) - `Profile` (`userId`, `displayName`, `createdAt`, `bio?`),
  `ProfileUpdateRequest` (`displayName?` or `bio?`, the absent one left out), `DisplayNameDraft` and `AboutDraft` (the
  typed text and its issues against `AppConfig.DisplayName` / `AppConfig.About`).
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `RemoteProfileRepository` (the three calls)
  and `MockProfileRepository` (Laurel's rules in memory: the default name on the first read, a rename trimmed and cut, a
  bio trimmed and cut and cleared by a blank).
- State: [./State/EGM.md](./State/EGM.md) - `ProfileStore`, the one source of the caller's profile: loaded once per
  signed-in session when Profile opens, replaced by a rename or a bio write, cleared with the session.
- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `ProfileFieldViewModel<Draft>`, the editors' shared
  `DraftSubmitting` model over the store, as `DisplayNameViewModel` and `AboutViewModel`.
- Views: [./Views/EGM.md](./Views/EGM.md) - `ProfileView` (the profile's name or the guest prompt, Sign in, a guest's
  feedback gated behind an account), `SettingsScreen` (pushed from the signed-in root: language, currency, contact,
  the privacy policy and the terms of use each pushed in place (owner correction and decision 2026-11-08), Sign out
  and Delete account), `LegalScreen` (the shared reading rendering), `PrivacyPolicyScreen` and `TermsScreen` (the
  policy and the terms read in place over `AppBranding.Privacy` / `AppBranding.Terms`, 2026-11-08), `DeleteAccountSheet` (the
  delete flow: summary, destructive confirm, locked wait, one-time acknowledgment), `DisplayNameRow` and
  `DisplayNameSheet`, `AboutRow` and `AboutSheet`, `LanguageRow` and
  `CurrencyRow` over the shared `SettingsChoiceRow` popover card.
