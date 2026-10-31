# Profile

Source: `lily/Features/Profile/`

## Overview

The Profile tab and the caller's backend profile. The tab shows the signed-in user (or the guest prompt with Sign in),
the language and currency settings as dropdown cards, the contact card and Sign out; `ProfileRepository` carries the
one thing the backend shows to others, the display name (`PUT /api/profile`), since identity stays with Cognito. No
source files live at this level; the four subdirectories below hold them.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `ProfileRepository` with `syncDisplayName(_:)`.
- Models: [./Models/EGM.md](./Models/EGM.md) - `Profile` (`userId`, `displayName`, `createdAt`) and
  `ProfileUpdateRequest` (`displayName`).
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `RemoteProfileRepository` (`PUT /api/profile`)
  and `MockProfileRepository` (accepts every name).
- Views: [./Views/EGM.md](./Views/EGM.md) - `ProfileView` (identity or guest prompt, Sign in and Sign out, feedback
  gated behind an account), `LanguageRow` and `CurrencyRow` over the shared `SettingsChoiceRow` popover card.
