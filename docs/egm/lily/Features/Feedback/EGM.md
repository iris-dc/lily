# lily/Features/Feedback

Source: `lily/Features/Feedback/`

## Overview

The contact form of iskra: a question, feedback or bug report typed on Profile and posted once to Laurel's
`POST /api/feedback`. The directory has no source files of its own; its five folders follow the project's layer
split. `Interfaces` declares `FeedbackRepository`; `Models` the `nonisolated` value types (`FeedbackKind`,
`FeedbackPayload`, `FeedbackReceipt`, `FeedbackDraft` with its issues, `FeedbackEnvironment`); `Implementations` the
remote and mock repositories; `ViewModels` the `FeedbackViewModel`; `Views` the Profile row and the form sheet. Data
flows Views → ViewModels → Interfaces → Implementations → Laurel. Contracts live out of tree under `docs/egm/`
because `lily/` may hold only Swift sources, catalogs and the privacy manifest.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `FeedbackRepository` with the single
  `send(_:) async throws -> FeedbackReceipt`; one send is one stored item, nothing is replayed.
- Models: [./Models/EGM.md](./Models/EGM.md) - the wire enum and payload (optionals omitted), the draft's
  validation against `AppConfig.Feedback` caps (message 2000, reply email 254, details 80) and the environment
  collected from `Bundle`, `ProcessInfo` and `uname`.
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `RemoteFeedbackRepository`
  (`POST /api/feedback`, fallback `.feedbackFailed`, no retry) and `MockFeedbackRepository` (in-memory `sent`,
  fabricated receipt).
- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `FeedbackViewModel`: `canSubmit` gating, one-shot
  `isSubmitted`, silent cancellation, error log plus `ErrorCenter.report` on failure.
- Views: [./Views/EGM.md](./Views/EGM.md) - `FeedbackRow` (on Settings when signed in, inline on a guest's profile
  root since 2026-11-07) and `FeedbackSheet` with its own `.errorPopup`, `DraftSubmitButton` and dismissal rules.
