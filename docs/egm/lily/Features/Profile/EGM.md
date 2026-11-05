# Profile

Source: `lily/Features/Profile/`

## Overview

The Profile tab and the caller's backend profile. The tab shows the signed-in user (the name other players see and the
bio under it, each with the card that edits it, and the account's email) or the guest prompt with Sign in, the language
and currency settings as dropdown cards, the contact card and Sign out. The display name and the bio are what the
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
- Views: [./Views/EGM.md](./Views/EGM.md) - `ProfileView` (the profile's name or the guest prompt, Sign in and Sign
  out, feedback gated behind an account), `DisplayNameRow` and `DisplayNameSheet`, `AboutRow` and `AboutSheet`,
  `LanguageRow` and `CurrencyRow` over the shared `SettingsChoiceRow` popover card.
