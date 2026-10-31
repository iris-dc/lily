# Feedback ViewModels

Source: `lily/Features/Feedback/ViewModels/`

## Overview

`FeedbackViewModel` owns the contact form's state: a mutable `FeedbackDraft`, the `FeedbackEnvironment` captured when
the sheet opened, and the `isSubmitting` / `isSubmitted` flags. `submit()` sends `draft.payload(in: environment)`
through the injected `FeedbackRepository` ([Interfaces](../Interfaces/EGM.md)), flips `isSubmitted` on success and,
on a failure other than cancellation, logs at error and reports to `ErrorCenter`. Unlike the Events and Groups
drafts it does not conform to Core's `DraftSubmitting`; the sheet drives it directly.

## Interface

- `FeedbackViewModel` (`lily/Features/Feedback/ViewModels/FeedbackViewModel.swift`): `@Observable final class`.
  - `init(repository: any FeedbackRepository, environment: FeedbackEnvironment, replyEmail: String?,
    errorCenter: ErrorCenter, logger: any Logging)`.
  - State: `var draft: FeedbackDraft`, `let environment: FeedbackEnvironment`, `private(set) var isSubmitting`,
    `private(set) var isSubmitted`.
  - `var canSubmit: Bool`, `func submit() async`.
  - Not a `DraftSubmitting` conformer (`lily/Core/UI/Interfaces/DraftSubmitting.swift` wants `issues`, `isDone`,
    `prepare()`); it exposes `isSubmitted` instead and has no `issues` or `prepare()`.

## Invariants

- `canSubmit == draft.isValid && !isSubmitting` (`FeedbackViewModel.canSubmit`).
- `submit()` guards on `canSubmit`: a call while invalid or already in flight is a no-op; `isSubmitting` is set and
  reset by `defer` on every exit path.
- `isSubmitted` becomes `true` only after `repository.send` returns a receipt and is never reset; on failure nothing
  but `isSubmitting` changes, so Send stays available and nothing retries by itself (a second send would be a second
  stored item).
- Cancellation is silent: when `AppError.isCancellation(error)` the catch returns without logging or reporting.
- `init` builds `draft = FeedbackDraft(replyEmail: replyEmail)` (kind `.feedback`, empty message, the reply address
  prefilled or empty); the production factory (`lily/App/AppDependencies+Feedback.swift`) passes the signed-in user's
  email and `FeedbackEnvironment.current(languageCode:)`.
- `environment` is a `let`: the version, OS, device and language attached are those of the moment the sheet opened.
- No explicit isolation annotation: main-actor by the target's default (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).

## Side Effects

- `repository.send(draft.payload(in: environment))`: `POST /api/feedback` with `RemoteFeedbackRepository`, an
  in-memory append with the mock (`FeedbackViewModel.submit`).
- Logging: `logger.info(.feedback, "Feedback <id> sent (<kind>)")` on success;
  `logger.error(.feedback, "Feedback send failed (<kind>): <error>")` on a non-cancellation failure.
- `errorCenter.report(error)` after the error log, which wraps into `AppError` and sets the shared popup's current
  error (`lily/Core/Errors/ErrorCenter.swift`).
- No spawned tasks, no dismissal, no `Bundle` or `ProcessInfo` reads in this file.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Feedback/FeedbackViewModelTests.swift`).
