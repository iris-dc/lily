# Profile Models

Source: `lily/Features/Profile/Models/`

## Overview

The backend's `Profile` and the body of the display-name update, as `nonisolated` `Codable` values with the backend's
key names, and `DisplayNameDraft`, the name as typed with its validation against `AppConfig.DisplayName`, measured in
code points as Laurel measures it, so a name that passes here is stored as typed, never cut.

## Interface

- `Profile: Codable, Hashable, Sendable` `[lily/Features/Profile/Models/Profile.swift:Profile]`: `userId`,
  `displayName`, `createdAt: Date`.
- `ProfileUpdateRequest: Codable, Hashable, Sendable` `[lily/Features/Profile/Models/Profile.swift:ProfileUpdateRequest]`:
  `displayName`; the body of `PUT /api/profile`.
- `DisplayNameDraft: Equatable, Sendable` `[lily/Features/Profile/Models/DisplayNameDraft.swift:DisplayNameDraft]`:
  `var name` (`init(name: = "")`), `trimmedName`, `issues: [Issue]`, `isValid`, `hint: String?`; nested
  `Issue: Equatable, Sendable` with `nameMissing`, `nameTooLong`.

## Invariants

- `Profile` and `ProfileUpdateRequest` are `nonisolated`, `Sendable`, `let`-only, with synthesized `Codable`
  `[lily/Features/Profile/Models/Profile.swift:Profile]`, `[lily/Features/Profile/Models/Profile.swift:ProfileUpdateRequest]`.
- `DisplayNameDraft` and its nested `Issue` are `nonisolated` as well
  `[lily/Features/Profile/Models/DisplayNameDraft.swift:DisplayNameDraft]`.
- `DisplayNameDraft.issues` is `[.nameMissing]` for a blank trimmed name, `[.nameTooLong]` when
  `trimmedName.codePointCount` is over `AppConfig.DisplayName.length.upperBound` (32), else empty;
  `isValid == issues.isEmpty`; `hint` is `AppBranding.DisplayName.tooLong(limit:)` for `.nameTooLong` only, a missing
  name keeping Save disabled without a line `[lily/Features/Profile/Models/DisplayNameDraft.swift:DisplayNameDraft.issues]`,
  `[lily/Features/Profile/Models/DisplayNameDraft.swift:DisplayNameDraft.hint]`.

## Side Effects

- `DisplayNameDraft.hint` reads copy through `AppBranding` (`localized(_:)`). Nothing else: value types.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Profile/DisplayNameDraftTests.swift`)
