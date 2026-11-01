# Profile ViewModels

Source: `lily/Features/Profile/ViewModels/`

## Overview

`DisplayNameViewModel`, the display name editor's model behind the shared `DraftSheet` (`lily/Core/UI/Components`):
one draft, Save for a changed valid name, the store's rename as the write, the backend's answer as the new name. A
refusal reaches the popup and keeps the draft for a repeat; a cancellation stays quiet.

## Interface

- `@Observable final class DisplayNameViewModel: DraftSubmitting`
  `[lily/Features/Profile/ViewModels/DisplayNameViewModel.swift:DisplayNameViewModel]`:
  `init(store: ProfileStore, errorCenter: ErrorCenter, logger: any Logging)`; `var draft: DisplayNameDraft`,
  `private(set) var isSubmitting`, `private(set) var isDone`, `issues`, `canSubmit`; `prepare() async`, `submit() async`.

## Invariants

- The draft starts from the store's name, or empty while it is unknown; `prepare()` loads the store and fills an empty
  field once the name is known, never overwriting what the user typed
  `[lily/Features/Profile/ViewModels/DisplayNameViewModel.swift:prepare]`.
- `canSubmit` is `!isSubmitting && draft.isValid && draft.trimmedName != (store.displayName ?? "")`: the comparison reads
  the store when judged, so a name typed before a slow load answered counts as unchanged once the load shows the same
  name, and anything valid may be saved while the name is unknown, since the write does not need the read
  `[lily/Features/Profile/ViewModels/DisplayNameViewModel.swift:canSubmit]`.
- `submit()` returns at once unless `canSubmit`; it sends `draft.trimmedName` through `store.rename(to:)`, sets `isDone`
  on the answer, reports every other failure to `ErrorCenter` with an error log, and a cancellation neither logs nor
  reports `[lily/Features/Profile/ViewModels/DisplayNameViewModel.swift:submit]`.

## Side Effects

- `ProfileStore.loadIfNeeded()` and `rename(to:)` (and through them the two profile routes); `ErrorCenter.report(_:)`
  on a failure; an `.auth` error log "Display name update failed" (the error, never the name)
  `[lily/Features/Profile/ViewModels/DisplayNameViewModel.swift:DisplayNameViewModel]`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Profile/DisplayNameViewModelTests.swift`); the sheet end to end:
  `LilyProfileTests.testChoosingADisplayNameOnProfileShowsIt` in `./scripts/ci.sh ui`.
