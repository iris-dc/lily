# Feedback Models

Source: `lily/Features/Feedback/Models/`

## Overview

The value types of the contact form: `FeedbackKind` (the wire enum `contact` / `feedback` / `bug`),
`FeedbackPayload` (the POST body, optionals omitted), `FeedbackReceipt` (what the backend answers), `FeedbackDraft`
(form state, validation against `AppConfig.Feedback` limits and the one `payload(in:)` builder), `FeedbackField` and
`FeedbackIssue` (per-field validation outcomes with their hint copy), and `FeedbackEnvironment` with `DeviceModel`
(app version, OS version, device identifier and language, read from `Bundle`, `ProcessInfo` and `uname`). All types
are `nonisolated`; every type but the caseless `DeviceModel` namespace is `Sendable`.

## Interface

- `FeedbackKind` (`lily/Features/Feedback/Models/Feedback.swift`): `enum: String, CaseIterable, Codable, Sendable`,
  cases `contact`, `feedback`, `bug`; `displayName` and `messagePlaceholder` from `AppBranding.Feedback`.
- `FeedbackPayload` (`Feedback.swift`): `Encodable, Equatable, Sendable`; `kind: FeedbackKind`, `message: String`,
  `replyEmail: String?`, `appVersion: String?`, `osVersion: String?`, `device: String?`, `locale: String?`;
  synthesized encoding, memberwise init, not `Decodable`.
- `FeedbackReceipt` (`Feedback.swift`): `Hashable, Codable, Sendable`; `id: String`, `createdAt: Date`.
- `FeedbackDraft` (`lily/Features/Feedback/Models/FeedbackDraft.swift`): `Equatable, Sendable`; `kind`, `message`,
  `replyEmail: String`; `init(kind: = .feedback, message: = "", replyEmail: String? = nil)`; `trimmedMessage`,
  `trimmedEmail`, `issues: [FeedbackIssue]`, `isValid`, `hint(for: FeedbackField) -> String?`,
  `payload(in: FeedbackEnvironment) -> FeedbackPayload`.
- `FeedbackField` (`FeedbackDraft.swift`): `message`, `replyEmail`. `FeedbackIssue` (`FeedbackDraft.swift`):
  `messageMissing`, `messageTooLong`, `emailInvalid`, `emailTooLong`; `field: FeedbackField`, `hint: String?`.
- `FeedbackEnvironment` (`lily/Features/Feedback/Models/FeedbackEnvironment.swift`): `Equatable, Sendable`;
  `appVersion`, `osVersion`, `device`, `locale: String`; `summary`;
  `static current(appVersion: AppVersion = .current(), languageCode: String)` (reads `ProcessInfo.processInfo`
  itself);
  `static osVersionText(_ version: OperatingSystemVersion) -> String`.
- `DeviceModel` (`FeedbackEnvironment.swift`): `static identifier(environment: [String: String]) -> String` (no
  default; every caller passes the environment); private `machine()`.

## Invariants

- `FeedbackDraft.issues`, in form order and at most one per field: `.messageMissing` when `trimmedMessage.isEmpty`,
  else `.messageTooLong` when `trimmedMessage.wireLength` (UTF-16 units) exceeds `AppConfig.Feedback.messageMaxLength`
  (2000); then, only when `trimmedEmail` is non-empty (a blank reply address is valid), `.emailInvalid` when
  `!CredentialsValidator.isValidEmail(trimmedEmail)`, else `.emailTooLong` when it exceeds
  `AppConfig.Feedback.replyEmailMaxLength` (254). `isValid == issues.isEmpty`.
- `FeedbackIssue.hint`: `.messageTooLong` and `.emailTooLong` map to `AppBranding.Feedback.tooLong(limit:)` with the
  respective cap, `.emailInvalid` to `AppBranding.Feedback.invalidEmail`, `.messageMissing` to `nil`, so a missing
  message shows no footer copy and only keeps `isValid` false. `hint(for:)` is the first issue of that field.
- `FeedbackDraft.init` stores `replyEmail ?? ""`; the stored property is never optional.
- `FeedbackDraft.payload(in:)` is the only place a draft becomes a payload: `message = trimmedMessage`,
  `replyEmail = replyEmail.nonBlankTrimmed` (`nil` when blank, so the key is omitted), `appVersion`, `osVersion` and
  `device` cut to `prefix(wireLength: AppConfig.Feedback.detailMaxLength)` (80 UTF-16 units on a character boundary),
  `locale` uncut, `kind` passed through.
- `FeedbackPayload`'s five optionals use synthesized `Encodable`, so a `nil` is omitted and never sent as `null`
  (`Feedback.swift`). `FeedbackKind` raw values are the wire names; `allCases` order is `contact`, `feedback`, `bug`.
- `FeedbackEnvironment.current`: `appVersion = AppVersion.headerValue` ("marketing (build)" from
  `CFBundleShortVersionString` and `CFBundleVersion`, `"0"` for a missing key); `osVersion =
  osVersionText(ProcessInfo.processInfo.operatingSystemVersion)`, which is `"\(AppConfig.Feedback.osName) major.minor"` with
  `.patch` appended only when non-zero; `device = DeviceModel.identifier(environment:)`; `locale` is the
  `languageCode` argument verbatim. `summary` joins `appVersion`, `osVersion` and `device` through
  `AppBranding.Groups.caption` (the dot every caption uses) and leaves `locale` out.
- `DeviceModel.identifier` returns `environment[AppConfig.Feedback.simulatorModelKey]`
  (`SIMULATOR_MODEL_IDENTIFIER`) when present and non-empty, else `utsname().machine` (e.g. `iPhone17,1`).

## Side Effects

- `FeedbackEnvironment.current` reads `Bundle.main.infoDictionary` through its `appVersion` default
  (`AppVersion.current()`) and, in its body, `ProcessInfo.processInfo.operatingSystemVersion` and `.environment`, which
  it hands to `DeviceModel.identifier(environment:)` (`FeedbackEnvironment.swift`).
- `DeviceModel.machine` calls `uname(&utsname)` and rebinds `machine` to `CChar` to build the string
  (`FeedbackEnvironment.swift`).
- `FeedbackKind` and `FeedbackDraft` have none: pure computed properties over `AppConfig` and `AppBranding` statics.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Feedback/FeedbackDraftTests.swift`).
