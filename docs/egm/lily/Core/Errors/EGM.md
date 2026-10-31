# Errors

Source: `lily/Core/Errors/`

## Overview

The app's single typed failure and the one funnel that shows it. `AppError` is the `nonisolated`, `Equatable`, `Sendable`
enum every repository and service throws (90 cases), with `wrapping(_:)` to normalise any thrown error and
`isCancellation(_:)` to tell a caller leaving mid-request from a fault. `ErrorMessageMapper` turns every case into a
localized `ErrorMessage` through one exhaustive switch that routes to per-area `nonisolated extension` files, each
chaining to the next and ending in `unknownMessage`. `ErrorCenter`, an `@Observable` main-actor class mounted once on
the root, holds the error on screen, logs what the user was shown and tracks popup presenters so only the topmost mount
draws.

## Interface

- `AppError` (`lily/Core/Errors/AppError.swift:AppError`): `nonisolated enum: Error, Equatable, Sendable`, one flat case list:
  - auth: `authCancelled`, `authFailed(provider: AuthProvider.Kind)`, `providerUnavailable(provider: AuthProvider.Kind)`,
    `invalidCredentials`, `emailTaken`, `emailNotConfirmed`, `invalidConfirmationCode`, `tooManyAttempts`, `sessionExpired`;
  - transport: `rateLimited(retryAfter: TimeInterval?)`, `network`;
  - events: `eventsUnavailable`, `eventNotFound`, `eventFull`, `alreadyJoined`, `notAParticipant`, `hostCannotLeave`,
    `tryAgain`, `participationFailed`, `eventCreationFailed`, `notHost`, `capacityTooLow`, `eventUpdateFailed`;
  - groups and invites: `groupsUnavailable`, `groupNotFound`, `groupFull`, `notAMember`, `bannedFromGroup`, `memberBanned`,
    `ownerCannotLeave`, `insufficientRole`, `membershipLimitReached`, `groupCreationFailed`, `groupActionFailed`,
    `contentRejected`, `inviteExpired`, `inviteUnavailable`, `inboxUnavailable`, `inviteActionFailed`, `inviteNotPending`,
    `alreadyMember`, `cannotInvite`;
  - chat, attachments, polls and pins: `chatUnavailable`, `messageSendFailed`, `messageNotFound`, `replyTargetNotFound`,
    `attachmentNotFound`, `attachmentTooLarge(caps: AttachmentCaps)`, `attachmentTypeNotAllowed`, `attachmentsDisabled`,
    `attachmentUploadFailed`, `attachmentUnavailable`, `pollsNotAllowed`, `notAPoll`, `pollAnonymous`, `voteFailed`,
    `notPinnable`, `tooManyPins`, `pinFailed`;
  - moderation and people: `reportFailed`, `blockLimitReached`, `userNotFound`, `accountSuspended`, `termsRequired`,
    `feedbackFailed`, `profileUnavailable`, `conversationFailed`, `conversationLimit`;
  - tournaments: `tournamentsUnavailable`, `tournamentNotFound`, `tournamentCreationFailed`, `tournamentUpdateFailed`,
    `tournamentActionFailed`, `registrationClosed`, `tournamentFull`, `alreadyEntered`, `teamFull`, `entryNotFound`,
    `notOrganizer`, `tournamentLocked`, `notEnoughEntries`, `notInMatch`, `matchNotReady`, `matchNotFound`,
    `drawNotAllowed`, `tournamentLimit`, `tournamentMembershipLimit`, `inviteeAlreadyEntered`, `cannotInviteToTournament`;
  - and `unknown`.
- `AppError.wrapping(_ error: any Error) -> AppError`, `AppError.isCancellation(_ error: any Error) -> Bool`
  (`lily/Core/Errors/AppError.swift:wrapping`, `isCancellation`).
- `ErrorMessage` (`lily/Core/Errors/ErrorMessageMapper.swift:ErrorMessage`): `nonisolated struct: Equatable, Sendable`;
  `title`, `body`.
- `ErrorMessageMapper` (`lily/Core/Errors/ErrorMessageMapper.swift:ErrorMessageMapper`): `nonisolated enum`;
  `static message(for: AppError) -> ErrorMessage`; `static var unknownMessage`; private `authMessage(for:)` and
  `eventMessage(for:)` in the main file. Per-area `nonisolated extension`s: `hostMessage(for:)`
  (`ErrorMessageMapper+Events.swift`); `groupMessage(for:)` and `moderationMessage(for:)` (`+Groups.swift`, private
  `groupWriteMessage`, `inviteMessage`, `membershipLimitMessage`, `accountSuspendedMessage`); `chatMessage(for:)` and
  `attachmentMessage(for:)` (`+Chat.swift`, private `attachmentCapsBody(_:)`); `pollAndPinMessage(for:)` (`+Polls.swift`);
  `peopleMessage(for:)` (`+People.swift`); `tournamentMessage(for:)` (`+Tournaments.swift`, private `entryMessage`,
  `matchMessage`, `tournamentInviteMessage`, `tournamentLimitMessage`, `tournamentMembershipLimitMessage`).
- `PresentedError` (`lily/Core/Errors/ErrorCenter.swift:PresentedError`): `struct: Identifiable, Equatable` (main-actor);
  `id: UUID`, `error: AppError`, `message: ErrorMessage`.
- `ErrorCenter` (`lily/Core/Errors/ErrorCenter.swift:ErrorCenter`): `@Observable final class`;
  `init(logger: any Logging, autoDismissDelay: Duration? = AppConfig.ErrorPopup.autoDismissDelay)`;
  `private(set) var current: PresentedError?`, `private(set) var presenters: [UUID]`, `let autoDismissDelay: Duration?`;
  `report(_: AppError)`, `report(_: any Error)`, `dismiss(_ id: PresentedError.ID? = nil)`,
  `beginPresenting(_: UUID)`, `endPresenting(_: UUID)`, `isTopPresenter(_: UUID) -> Bool`.

## Invariants

- `message(for:)` is an exhaustive `switch` over all 90 cases with no `default`, so a new `AppError` case that is not
  routed is a compile error; `.network` and `.rateLimited` are answered inline (the `retryAfter` value is not used in the
  copy), every other case goes to an area function (`ErrorMessageMapper.swift:message(for:)`).
- Every area switch ends in a `default` that chains or returns `unknownMessage`, so no path traps:
  `eventMessage -> hostMessage`, `groupMessage -> groupWriteMessage -> inviteMessage`, `chatMessage -> pollAndPinMessage`,
  `peopleMessage -> tournamentMessage -> entryMessage -> matchMessage -> tournamentInviteMessage`; `authMessage`,
  `attachmentMessage` and `moderationMessage` fall straight to `unknownMessage` (`ErrorMessageMapper*.swift`).
- Every title and body is read through `localized(_:)` (`lily/Core/Localization/Localized.swift`); the limits in the copy
  come from `AppConfig` (`Groups.maxMemberships`, `Moderation.supportEmail`, `People.maxConversations`,
  `Tournaments.maxOrganizedOpen`, `Tournaments.maxPerUser`, `Chat.Attachments.videoMaxDurationSeconds`); the
  attachment-too-large body is computed from the `AttachmentCaps` carried in the error, bytes to MiB (1024 x 1024) by integer division
  (`ErrorMessageMapper+Chat.swift:attachmentCapsBody`).
- `wrapping` in order: an `AppError` unchanged; a `CancellationError` to `.authCancelled`; any `URLError` to `.network`;
  anything else to `.unknown` (`AppError.swift:wrapping`). `isCancellation` is true when the current task is cancelled,
  the error is a `CancellationError`, or a `URLError` with code `.cancelled`; such errors are never shown
  (`AppError.swift:isCancellation`).
- `ErrorCenter.report` filters, de-duplicates and queues nothing: each call replaces `current` with a
  `PresentedError` carrying a fresh `UUID`, so an identical error re-animates; `report(_: any Error)` goes through
  `AppError.wrapping` first. `dismiss(nil)` always clears `current`; `dismiss(id)` only when it is the current one
  (`ErrorCenter.swift:report`, `dismiss`).
- `beginPresenting` removes then appends the presenter, so each appears once and the latest is last;
  `isTopPresenter` is true only for `presenters.last`, so an error raised while a sheet is up shows once, above the sheet
  (`ErrorCenter.swift:beginPresenting`, `isTopPresenter`).
- `autoDismissDelay` is only stored: `nil` keeps the popup up until dismissed (`-hold-popups`); the view schedules the
  dismissal, nothing in this directory does (`ErrorCenter.swift:autoDismissDelay`).
- `AppError`, `ErrorMessage` and `ErrorMessageMapper` are `nonisolated`, and all six per-area files are
  `nonisolated extension ErrorMessageMapper`, so copy can be read from any isolation; `PresentedError` and `ErrorCenter`
  are main-actor. The split into chained files keeps each switch under SwiftLint's complexity limit.

## Side Effects

- `ErrorCenter.report` logs `"Presenting error: <error>"` at info under `.ui` on every call: the fault itself is logged
  where it happened, this line records what the user was shown (`ErrorCenter.swift:report`).
- Observable mutations: `current` (report, dismiss) and `presenters` (begin/endPresenting) (`ErrorCenter.swift`).
- No `Task`, `Timer` or sleep anywhere in the directory. The mapper is pure: `localized(_:)` and `AppConfig` reads only.
- `AppError.isCancellation` reads the calling task's `Task.isCancelled` (`AppError.swift:isCancellation`).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites live under `lilyTests/Errors`).
