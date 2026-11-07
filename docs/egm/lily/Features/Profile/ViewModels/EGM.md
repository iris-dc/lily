# Profile ViewModels

Source: `lily/Features/Profile/ViewModels/`

## Overview

`ProfileFieldViewModel<Draft: ProfileFieldDraft>`, the one editor model behind the shared `DraftSheet`
(`lily/Core/UI/Components`) for both texts of the caller's profile, as `DisplayNameViewModel`
(`ProfileFieldViewModel<DisplayNameDraft>`) and `AboutViewModel` (`ProfileFieldViewModel<AboutDraft>`): one draft,
Save for a changed valid text, the store's write of the field as the write, the backend's answer as the new value. A
refusal reaches the popup and keeps the draft for a repeat; a cancellation stays quiet. `ProfileField` names the field
and routes to the store. `DeleteAccountViewModel` (2026-11-07) is the delete flow's state machine behind
`DeleteAccountSheet`: the advisory plan, the confirm, the inverted-check poll and the one-time acknowledgment.

## Interface

- `enum ProfileField { displayName, bio }` `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:ProfileField]`:
  `current(in: ProfileStore) -> String?` (`store.displayName` / `store.bio`), `write(_:through:) async throws -> Profile`
  (`store.rename(to:)` / `store.updateBio(to:)`), `logSubject` ("Display name" / "About").
- `@Observable final class ProfileFieldViewModel<Draft: ProfileFieldDraft>: DraftSubmitting`
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:ProfileFieldViewModel]`:
  `init(field: ProfileField, store: ProfileStore, errorCenter: ErrorCenter, logger: any Logging)`; `var draft: Draft`,
  `private(set) var isSubmitting`, `private(set) var isDone`, `issues: [Draft.Issue]`, `canSubmit`; `prepare() async`,
  `submit() async`.
- `@Observable final class DeleteAccountViewModel`
  `[lily/Features/Profile/ViewModels/DeleteAccountViewModel.swift:DeleteAccountViewModel]` (2026-11-07, the deletion
  contract): `init(repository: any MeRepository, session: any AccountDeletionSession, errorCenter: ErrorCenter,
  logger: any Logging, sleep: Sleep = systemSleep)`; state `plan: DeletionPlan?`, `isLoadingPlan`, `isDeleting`,
  `isDeleted`, derived `isLocked` (`isDeleting || isDeleted`) and `summaryLines` (`nonisolated static
  lines(for: DeletionPlan?) -> [String]`, one `AppBranding.DeleteAccount` plural line per non-zero count in the plan's
  field order, zero-count lines dropped — the relocation contract's pinned rendering rule; the always-true messages
  sentence is the view's); `prepare() async`, `confirmDeletion() async`, `acknowledge() async`.
- `typealias DisplayNameViewModel = ProfileFieldViewModel<DisplayNameDraft>` and
  `typealias AboutViewModel = ProfileFieldViewModel<AboutDraft>`, each with a convenience
  `init(store:errorCenter:logger:)` fixing the field `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:DisplayNameViewModel]`,
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:AboutViewModel]`.

## Invariants

- The draft starts from the store's value of the field, or empty while it is unknown; `prepare()` loads the store and
  refills the field once the value is known only while the draft still equals the text it opened with, so an edit
  (an emptied bio included, which clears it) is never overwritten
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:prepare]`.
- `canSubmit` is `!isSubmitting && draft.isValid && draft.trimmedText != (field.current(in: store) ?? "")`: the
  comparison reads the store when judged, so a text typed before a slow load answered counts as unchanged once the load
  shows the same text, anything valid may be saved while the value is unknown (the write does not need the read), and
  an emptied field over a written bio is a change (it clears) while an empty field over no bio is none
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:canSubmit]`.
- `submit()` returns at once unless `canSubmit`; it sends `draft.trimmedText` through `field.write(_:through:)`, sets
  `isDone` on the answer, reports every other failure to `ErrorCenter` with an error log, and a cancellation neither
  logs nor reports `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:submit]`.

- `DeleteAccountViewModel`: `prepare()` loads the plan once and only while unlocked; a failure reports the popup and
  leaves `plan` nil, blocking nothing (the preview is advisory and must never stand between the caller and erasure) —
  except locked or landed (`DeletionSettle.isLanded`), which reports nothing and logs at debug: the account-deleted
  teardown re-instantiates the sheet's content, whose fresh `.task` re-runs `prepare()` against the dead session, and
  its 401 must never raise the "Session expired" popup over the signed-out landing (the design's client end path
  suppresses it) `[lily/Features/Profile/ViewModels/DeleteAccountViewModel.swift:prepare]`. `confirmDeletion()`
  is turned away while locked; it locks, calls `session.beginAccountDeletion()` (racing 401s end nothing under the
  locked sheet), sends `deleteAccount()`, then polls `me()` every `AppConfig.AccountDeletion.pollInterval` until
  `DeletionSettle.isLanded` says the deletion landed — an answering read means the job runs, any other failure settles
  on a later read, so the loop never gives up; a landed `deleteAccount()` refusal (the post-completion 401) lands at
  once with zero polls. A refusal before the claim unlocks, calls `cancelAccountDeletion()` and reports the popup.
  `acknowledge()` does nothing until `isDeleted` and is the only caller of `session.endDeletedSession()` — the
  relocation contract's pinned teardown order
  `[lily/Features/Profile/ViewModels/DeleteAccountViewModel.swift:confirmDeletion]`.

## Side Effects

- `ProfileStore.loadIfNeeded()` and `rename(to:)` or `updateBio(to:)` (and through them the profile routes);
  `ErrorCenter.report(_:)` on a failure; an `.auth` error log "<subject> update failed" ("Display name update failed",
  "About update failed"; the error, never the text)
  `[lily/Features/Profile/ViewModels/ProfileFieldViewModel.swift:ProfileFieldViewModel]`.
- `DeleteAccountViewModel`: `GET /api/me/deletion-plan`, `DELETE /api/me` and the `GET /api/me` poll through
  `MeRepository`; `session.beginAccountDeletion()` / `cancelAccountDeletion()` / `endDeletedSession()`;
  `ErrorCenter.report(_:)` on a plan failure or a pre-claim refusal. `.auth` logs, pinned as count plus fragment:
  info "Account deletion requested" and "Account deletion landed after <n> polls", warning "Deletion plan load
  failed", error "Account deletion request failed", debug "Account deletion poll unsettled", "Account deletion
  poll cancelled" and "Deletion plan load found the session ended" (a landed or locked plan load, never reported)
  `[lily/Features/Profile/ViewModels/DeleteAccountViewModel.swift:DeleteAccountViewModel]`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Profile/DisplayNameViewModelTests.swift`,
  `lilyTests/Profile/AboutViewModelTests.swift`, `lilyTests/Profile/DeleteAccountViewModelTests.swift` — the summary
  rule, the poll, the teardown order over a spy `AccountDeletionSession`); the sheets end to end:
  `LilyProfileTests.testChoosingADisplayNameOnProfileShowsIt`, `testWritingAboutYouOnProfileShowsIt` and
  `LilySettingsTests.testDeletingTheAccountWalksToTheSignedOutLanding` in `./scripts/ci.sh ui`.
