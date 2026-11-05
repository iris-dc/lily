# Profile ViewModels

Source: `lily/Features/Profile/ViewModels/`

## Overview

`ProfileFieldViewModel<Draft: ProfileFieldDraft>`, the one editor model behind the shared `DraftSheet`
(`lily/Core/UI/Components`) for both texts of the caller's profile, as `DisplayNameViewModel`
(`ProfileFieldViewModel<DisplayNameDraft>`) and `AboutViewModel` (`ProfileFieldViewModel<AboutDraft>`): one draft,
Save for a changed valid text, the store's write of the field as the write, the backend's answer as the new value. A
refusal reaches the popup and keeps the draft for a repeat; a cancellation stays quiet. `ProfileField` names the field
and routes to the store.

## Interface

- `enum ProfileField { displayName, bio }` `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:ProfileField]`:
  `current(in: ProfileStore) -> String?` (`store.displayName` / `store.bio`), `write(_:through:) async throws -> Profile`
  (`store.rename(to:)` / `store.updateBio(to:)`), `logSubject` ("Display name" / "About").
- `@Observable final class ProfileFieldViewModel<Draft: ProfileFieldDraft>: DraftSubmitting`
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:ProfileFieldViewModel]`:
  `init(field: ProfileField, store: ProfileStore, errorCenter: ErrorCenter, logger: any Logging)`; `var draft: Draft`,
  `private(set) var isSubmitting`, `private(set) var isDone`, `issues: [Draft.Issue]`, `canSubmit`; `prepare() async`,
  `submit() async`.
- `typealias DisplayNameViewModel = ProfileFieldViewModel<DisplayNameDraft>` and
  `typealias AboutViewModel = ProfileFieldViewModel<AboutDraft>`, each with a convenience
  `init(store:errorCenter:logger:)` fixing the field `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:DisplayNameViewModel]`,
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:AboutViewModel]`.

## Invariants

- The draft starts from the store's value of the field, or empty while it is unknown; `prepare()` loads the store and
  fills an empty field once the value is known, never overwriting what the user typed
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:prepare]`.
- `canSubmit` is `!isSubmitting && draft.isValid && draft.trimmedText != (field.current(in: store) ?? "")`: the
  comparison reads the store when judged, so a text typed before a slow load answered counts as unchanged once the load
  shows the same text, anything valid may be saved while the value is unknown (the write does not need the read), and
  an emptied field over a written bio is a change (it clears) while an empty field over no bio is none
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:canSubmit]`.
- `submit()` returns at once unless `canSubmit`; it sends `draft.trimmedText` through `field.write(_:through:)`, sets
  `isDone` on the answer, reports every other failure to `ErrorCenter` with an error log, and a cancellation neither
  logs nor reports `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:submit]`.

## Side Effects

- `ProfileStore.loadIfNeeded()` and `rename(to:)` or `updateBio(to:)` (and through them the profile routes);
  `ErrorCenter.report(_:)` on a failure; an `.auth` error log "<subject> update failed" ("Display name update failed",
  "About update failed"; the error, never the text)
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:ProfileFieldViewModel]`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Profile/DisplayNameViewModelTests.swift`,
  `lilyTests/Profile/AboutViewModelTests.swift`); the sheets end to end:
  `LilyProfileTests.testChoosingADisplayNameOnProfileShowsIt` and `testWritingAboutYouOnProfileShowsIt` in
  `./scripts/ci.sh ui`.
