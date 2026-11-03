# Feedback Views

Source: `lily/Features/Feedback/Views/`

## Overview

Two views. `FeedbackRow` is the tappable card on Profile that opens the form: a `SettingsLinkRow`
(`lily/Core/UI/Components`) given its copy and symbol, deferring everything to an injected closure. `FeedbackSheet` is the contact form: a `NavigationStack` with a segmented
`FeedbackKind` picker, a multi-line message field, a reply-email field with validation hints and the environment
summary in its footers, a Cancel/Send toolbar that becomes Done once the message was sent, its own error popup
mount, and swipe-to-dismiss blocked while sending. It drives `FeedbackViewModel`
([ViewModels](../ViewModels/EGM.md)) through Core's `DraftSubmitButton` rather than the generic `DraftSheet`.

## Interface

- `FeedbackRow` (`lily/Features/Feedback/Views/FeedbackRow.swift`): `let action: () -> Void`; a
  `SettingsLinkRow(title: AppBranding.Feedback.rowTitle, subtitle: rowSubtitle, systemImage: DesignTokens.Symbols.feedback,
  identifier: AccessibilityIdentifiers.profileFeedback, action:)`, the shared glass card with icon, title, subtitle and
  chevron (`lily/Core/UI/Components/SettingsLinkRow.swift`).
- `FeedbackSheet` (`lily/Features/Feedback/Views/FeedbackSheet.swift`): `init(viewModel: FeedbackViewModel,
  errorCenter: ErrorCenter)`; keeps the view model in `@State` (`State(initialValue:)`), reads
  `@Environment(\.dismiss)`. Private `form`, `hint(for: FeedbackField) -> ValidationHint?`, `toolbar` (Done and Cancel
  are `lilyToolbarTextButton()`). Identifiers:
  `feedbackMessage`, `feedbackEmail`, `feedbackSubmit`, `feedbackDone`
  (`lily/Config/AccessibilityIdentifiers+Feedback.swift`); the kind picker carries none, its segments are found by label.

## Invariants

- `FeedbackSheet.body` switches on `viewModel.isSubmitted`: `true` shows an `EmptyStateView` with
  `DesignTokens.Symbols.feedbackSent`, `Copy.thanks` and `Copy.thanksMessage`; `false` shows the form.
- Presentation `.presentationDetents([.large])` then `.lilyFormSheet(errorCenter: errorCenter, lockedWhile:
  viewModel.isSubmitting)` (`lily/Core/UI/Layout/FormSheet.swift`: form sizing, the grabber, interactive dismiss
  disabled while submitting and the popup mount in one modifier), `.tint(Color.lilyAccent)`, inline title `Copy.title`.
- The sheet mounts its own `.errorPopup(errorCenter)` through that modifier, since a sheet draws above the root's
  popup and only the last mounted presenter draws.
- Toolbar: when `isSubmitted`, one confirmation `Button(Copy.done)` → `dismiss()`; otherwise a cancellation
  `Button(AppBranding.Forms.cancel, role: .cancel)` → `dismiss()`, disabled while `isSubmitting`, and a
  confirmation `DraftSubmitButton(title: Copy.send, isSubmitting:, isEnabled: viewModel.canSubmit)` running
  `await viewModel.submit()`; Send is disabled whenever `canSubmit` is false and shows a `ProgressView` while sending.
- Form fields: a segmented `Picker` over `FeedbackKind.allCases` bound to `$viewModel.draft.kind`; a vertical-axis
  `TextField` with the kind's `messagePlaceholder`, sentence capitalisation and
  `.lineLimit(DesignTokens.Layout.feedbackMessageLines)`, footer `hint(for: .message)`; an email `TextField`
  (`.emailAddress` keyboard and content type, no capitalisation, no autocorrection) whose footer is
  `hint(for: .replyEmail)` or `Copy.replyEmailFooter`, followed by `Copy.attachedDetails(viewModel.environment.summary)`.
- `hint(for:)` maps `viewModel.draft.hint(for:)` to a `ValidationHint` (`lily/Core/UI/Components`: the words in
  `Color.secondary`, the plain colour rather than the hierarchical style, the accent on the glyph) and is `nil` when the draft has no hint for the field (so `.messageMissing`
  shows nothing); the email footer branches on it with `if let`, since a `ValidationHint` and a `Text` cannot share `??`.
- `FeedbackRow` is stateless; the guest-to-sign-in gating its doc comment mentions lives in the caller.

## Side Effects

- `dismiss()` from Done after a successful send and from Cancel while not submitting (`FeedbackSheet.toolbar`).
- `DraftSubmitButton` spawns `Task { await action() }` (`lily/Core/UI/Components/DraftSubmitButton.swift`), which runs
  `viewModel.submit()` and so the repository send, the `.feedback` log lines and `ErrorCenter.report` on failure.
- `.errorPopup(errorCenter)` (inside `lilyFormSheet(errorCenter:lockedWhile:)`) installs `ErrorPopupModifier`
  (`lily/Core/UI/Components/ErrorPopup.swift`) on the sheet,
  registering it as a presenter for the shared `ErrorCenter`.
- `FeedbackRow` invokes its `action` on tap; nothing else. No haptics, network, logging or process reads in this
  directory.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Feedback`); the sheet itself is exercised by
  `./scripts/ci.sh ui` (`lilyUITests`).
