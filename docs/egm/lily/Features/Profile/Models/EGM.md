# Profile Models

Source: `lily/Features/Profile/Models/`

## Overview

The backend's `Profile` and the body of a profile update, as `nonisolated` `Codable` values with the backend's key
names, and the two drafts, `DisplayNameDraft` and `AboutDraft`: a text as typed with its validation against
`AppConfig.DisplayName` or `AppConfig.About`, measured in code points as Laurel measures it, so a text that passes here
is stored as typed, never cut. Both drafts conform to `ProfileFieldDraft` ([Interfaces](../Interfaces/EGM.md)).

## Interface

- `Profile: Codable, Hashable, Sendable` `[lily/Features/Profile/Models/Profile.swift:Profile]`: `userId`,
  `displayName`, `createdAt: Date`, `bio: String?` (absent until written); `init(userId:displayName:createdAt:bio: = nil)`.
- `ProfileUpdateRequest: Codable, Hashable, Sendable` `[lily/Features/Profile/Models/Profile.swift:ProfileUpdateRequest]`:
  `displayName: String?`, `bio: String?`; `init(displayName:)` and `init(bio:)`, one field each; the body of
  `PUT /api/profile`.
- `DisplayNameDraft: ProfileFieldDraft` `[lily/Features/Profile/Models/DisplayNameDraft.swift:DisplayNameDraft]`:
  `var text` (`init(text: = "")`), `trimmedText`, `issues: [Issue]`, `isValid`, `hint: String?`; nested
  `Issue: Equatable, Sendable` with `nameMissing`, `nameTooLong`.
- `AboutDraft: ProfileFieldDraft` `[lily/Features/Profile/Models/AboutDraft.swift:AboutDraft]`: the same members;
  nested `Issue` with `tooLong` alone.

## Invariants

- `Profile` and `ProfileUpdateRequest` are `nonisolated`, `Sendable`, `let`-only, with synthesized `Codable`; the
  request's absent field is left out of the JSON (synthesized `encodeIfPresent`), never sent as `null`, so the backend
  changes one thing `[lily/Features/Profile/Models/Profile.swift:Profile]`,
  `[lily/Features/Profile/Models/Profile.swift:ProfileUpdateRequest]`.
- The drafts and their nested `Issue`s are `nonisolated` as well
  `[lily/Features/Profile/Models/DisplayNameDraft.swift:DisplayNameDraft]`, `[lily/Features/Profile/Models/AboutDraft.swift:AboutDraft]`.
- `DisplayNameDraft.issues` is `[.nameMissing]` for a blank trimmed text, `[.nameTooLong]` when
  `trimmedText.codePointCount` is over `AppConfig.DisplayName.length.upperBound` (32), else empty;
  `isValid == issues.isEmpty`; `hint` is `AppBranding.DisplayName.tooLong(limit:)` for `.nameTooLong` only, a missing
  name keeping Save disabled without a line `[lily/Features/Profile/Models/DisplayNameDraft.swift:DisplayNameDraft.issues]`,
  `[lily/Features/Profile/Models/DisplayNameDraft.swift:DisplayNameDraft.hint]`.
- `AboutDraft.issues` is `[.tooLong]` when `trimmedText.codePointCount` is over `AppConfig.About.maxLength` (300), else
  empty: a blank is valid, since it clears the bio; `hint` is `AppBranding.About.tooLong(limit:)` for `.tooLong`
  `[lily/Features/Profile/Models/AboutDraft.swift:AboutDraft.issues]`, `[lily/Features/Profile/Models/AboutDraft.swift:AboutDraft.hint]`.

## Side Effects

- The drafts' `hint`s read copy through `AppBranding` (`localized(_:)`). Nothing else: value types.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Profile/DisplayNameDraftTests.swift`, `lilyTests/Profile/AboutDraftTests.swift`;
  `RemoteProfileRepositoryTests` pins the request's JSON)
