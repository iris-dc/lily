# Profile

Source: `lily/Features/Profile/`

## Overview

The Profile tab and the caller's backend profile. The tab shows the signed-in user (the name other players see, with
the card that edits it, and the account's email) or the guest prompt with Sign in, the language and currency settings
as dropdown cards, the contact card and Sign out. The display name is the one thing the backend shows to others and the
user chooses it here: every profile starts as the backend's default ("Player", `AppConfig.DisplayName.backendDefault`)
until a rename through `PUT /api/profile`; nothing is derived from the email, since identity stays with Cognito. No
source files live at this level; the six subdirectories below hold them.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `ProfileRepository` with `profile()` (`GET /api/profile`)
  and `updateDisplayName(_:)` (`PUT /api/profile`).
- Models: [./Models/EGM.md](./Models/EGM.md) - `Profile` (`userId`, `displayName`, `createdAt`),
  `ProfileUpdateRequest` (`displayName`) and `DisplayNameDraft` (the typed name and its issues against
  `AppConfig.DisplayName`).
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `RemoteProfileRepository` (the two routes)
  and `MockProfileRepository` (Laurel's rules in memory: the default name on the first read, a rename trimmed and cut).
- State: [./State/EGM.md](./State/EGM.md) - `ProfileStore`, the one source of the caller's profile: loaded once per
  signed-in session when Profile opens, replaced by a rename, cleared with the session.
- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `DisplayNameViewModel`, the editor's `DraftSubmitting`
  model over the store.
- Views: [./Views/EGM.md](./Views/EGM.md) - `ProfileView` (the profile's name or the guest prompt, Sign in and Sign
  out, feedback gated behind an account), `DisplayNameRow` and `DisplayNameSheet`, `LanguageRow` and `CurrencyRow` over
  the shared `SettingsChoiceRow` popover card.
