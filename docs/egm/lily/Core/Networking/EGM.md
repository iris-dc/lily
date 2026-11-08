# Networking

Source: `lily/Core/Networking/`

## Overview

The networking seam to Laurel and the rules every backend call follows. A repository builds an `APIRequest` and calls
`client.send(request, failingWith: fallback)`: the client (`Implementations/`) talks `URLSession` and JSON, and the
direct files here turn an `APIError` into the typed `AppError` the screens show (`APIFailureMapping.swift`), repeat a
write that lost a race once (`LostRace`, `WriteGate`), read a write whose answer was lost back before any popup
(`LostAnswer`), settle a create whose answer was lost by looking it up under its client id or, after a `*_ID_REUSED`,
updating it (`CreateFlow`), and read a download with progress (`ProgressDataTask`). Paths, header names, status codes and
timeouts live in `AppConfig.API` (`lily/Config/`) and are cited by name.

## Interface

- Children: [Interfaces](./Interfaces/EGM.md) (`APIClient`), [Models](./Models/EGM.md) (`APIRequest`, `APIError`,
  `AppVersion`, `Page`, `NoContent`, `OptionalBody`, `WireNamedKind`, `Coordinate.queryItems`),
  [Implementations](./Implementations/EGM.md) (`URLSessionAPIClient`, `APIJSONCoding`).
- `nonisolated enum BackendErrorCode: String, CaseIterable, Sendable`: 61 cases whose raw values are Laurel's codes
  (`EVENT_NOT_FOUND`, `EVENT_FULL`, `ALREADY_JOINED`, `NOT_A_PARTICIPANT`, `HOST_CANNOT_LEAVE`, `NOT_HOST`,
  `CAPACITY_TOO_LOW`, `TRY_AGAIN`, `RATE_LIMITED`, `REQUEST_TOO_LARGE`, `CONTENT_REJECTED`, `FORBIDDEN`, `NOT_A_MEMBER`, `BANNED`,
  `ACCOUNT_SUSPENDED`, `TERMS_REQUIRED`, `GROUP_NOT_FOUND`, `MESSAGE_NOT_FOUND`, `USER_NOT_FOUND`, `EVENT_ID_TAKEN`, `EVENT_ID_REUSED`,
  `GROUP_ID_TAKEN`, `GROUP_ID_REUSED`, `GROUP_FULL`, `OWNER_CANNOT_LEAVE`, `MEMBER_BANNED`, `MEMBERSHIP_LIMIT`, `INVITE_EXPIRED`,
  `INVITE_NOT_PENDING`, `INBOX_ITEM_NOT_FOUND`, `ALREADY_MEMBER`, `CANNOT_INVITE`, `INVITE_LIMIT`, `BLOCK_LIMIT`, `CONVERSATION_LIMIT`,
  `REPLY_TARGET_NOT_FOUND`, `ATTACHMENT_NOT_FOUND`, `ATTACHMENT_TOO_LARGE`, `ATTACHMENT_TYPE_NOT_ALLOWED`,
  `ATTACHMENTS_DISABLED`, `POLLS_NOT_ALLOWED`, `NOT_A_POLL`, `POLL_ANONYMOUS`, `NOT_PINNABLE`, `TOO_MANY_PINS`,
  `TOURNAMENT_NOT_FOUND`, `TOURNAMENT_ID_TAKEN`, `TOURNAMENT_ID_REUSED`, `TOURNAMENT_LIMIT`, `NOT_ORGANIZER`,
  `TOURNAMENT_LOCKED`, `REGISTRATION_CLOSED`, `TOURNAMENT_FULL`, `ALREADY_ENTERED`, `TEAM_FULL`, `ENTRY_NOT_FOUND`,
  `NOT_ENOUGH_ENTRIES`, `MATCH_NOT_FOUND`, `NOT_IN_MATCH`, `MATCH_NOT_READY`, `DRAW_NOT_ALLOWED`); `var appError: AppError`
  [`lily/Core/Networking/APIFailureMapping.swift:BackendErrorCode`]. Laurel's 69 codes are these 61 plus eight with no case
  on purpose: the framework codes `VALIDATION_FAILED`, `UNAUTHENTICATED`, `INTERNAL_ERROR`, `NOT_FOUND`, `METHOD_NOT_ALLOWED`,
  `UNSUPPORTED_MEDIA_TYPE` and the operator codes `REPORT_NOT_FOUND`, `FEEDBACK_NOT_FOUND`, which fall to the route's fallback.
- `extension APIError { func appError(fallback: AppError) -> AppError }` [`lily/Core/Networking/APIFailureMapping.swift:APIError.appError(fallback:)`].
- `extension APIClient { func send<Response: Decodable>(_ request: APIRequest<Response>, failingWith fallback: AppError) async throws -> Response }`
  [`lily/Core/Networking/APIFailureMapping.swift:APIClient.send(_:failingWith:)`].
- `enum LostRace` (main-actor): `static func attemptTwice<Value>(delay: Duration, sleep: Sleep = systemSleep, logger: any Logging, category: LogCategory, retrying what: String, _ attempt: () async throws -> Value) async throws -> Value`
  [`lily/Core/Networking/LostRace.swift:LostRace.attemptTwice`].
- `struct WriteGate` (main-actor): `category: LogCategory`, `logger`, `tryAgainDelay: Duration`,
  `report: (any Error) -> Void`, `var isExpected: (AppError) -> Bool = { _ in false }`;
  `@discardableResult func run(_ what: String, _ work: () async throws -> Void) async -> Bool` and
  `@discardableResult func run(_ what: String, settling: (any Error) async -> Bool, _ work: () async throws -> Void) async -> Bool`
  [`lily/Core/Networking/WriteGate.swift:WriteGate`].
- `struct LostAnswer<State>` (main-actor): `category: LogCategory`, `logger`, `leavesOutcomeUnknown: (AppError) -> Bool`,
  `var isWorthAnotherLook: (AppError) -> Bool = { _ in false }`, `refetch: () async throws -> State`,
  `apply: (State) -> Void`; `enum Settlement: Equatable { landed, didNotLand, unresolved; var isLanded: Bool }`;
  `func settle(_ what: String, despite error: any Error, intent: (State) -> Bool?) async -> Settlement`
  [`lily/Core/Networking/LostAnswer.swift:LostAnswer`].
- `struct CreateFlow<Created: Identifiable> where Created.ID == String` (main-actor): `noun`, `category`, `logger`,
  `tryAgainDelay: Duration`, `var sleep: Sleep = systemSleep`, `report: (any Error) -> Void`,
  `leavesOutcomeUnknown: (AppError) -> Bool`, `notFound: AppError`, `lookup: (String) async throws -> Created`,
  `isOurs: (Created) -> Bool`;
  `func submit(clientID: String, describing: (Created) -> String, send: () async throws -> Created, update: () async throws -> Created) async -> Created?`
  [`lily/Core/Networking/CreateFlow.swift:CreateFlow`].
- `nonisolated enum ProgressDataTask`: `static func run(_ url: URL, in session: URLSession, progress: (@MainActor @Sendable (Double) -> Void)?) async throws -> (Data, URLResponse)`;
  private `TaskHandle: Sendable` over a `Mutex<State>` from `Synchronization`
  [`lily/Core/Networking/ProgressDataTask.swift:ProgressDataTask.run(_:in:progress:)`].

## Invariants

- `BackendErrorCode.appError` is an exhaustive switch (a new code without a mapping fails to compile; exhaustive as a
  switch, not as a copy of Laurel's list). Same-named cases map one to one; the exceptions are `rateLimited` to
  `.rateLimited(retryAfter: nil)`, `forbidden` to `.insufficientRole`, `banned` to `.bannedFromGroup`, `eventIdTaken` to
  `.eventCreationFailed`, `groupIdTaken` to `.groupCreationFailed`, `eventIdReused`, `groupIdReused` and
  `tournamentIdReused` to `.createIdReused`, `membershipLimit` to `.membershipLimitReached`, `inviteNotPending` and
  `inboxItemNotFound` to `.inviteNotPending`, `inviteLimit` to `.tournamentInviteLimit`, `blockLimit` to
  `.blockLimitReached`, `attachmentTooLarge` to `.attachmentTooLarge(caps: .group)`, `tournamentIdTaken` to
  `.tournamentCreationFailed` [`APIFailureMapping.swift:BackendErrorCode.appError`].
- `APIError.appError(fallback:)`: a non-`.http` error is the fallback; `AppConfig.API.unauthorizedStatus` is
  `.sessionExpired`, `AppConfig.API.rateLimitedStatus` is `.rateLimited(retryAfter:)` and
  `AppConfig.API.contentTooLargeStatus` is `.requestTooLarge`, all three before the body is read (they may come without
  one); a known body code maps through `BackendErrorCode`; anything else is the fallback
  [`APIFailureMapping.swift:APIError.appError(fallback:)`].
- `send(_:failingWith:)`: an `APIError` becomes its `appError(fallback:)`; a `URLError` other than `.cancelled`
  becomes `AppError.network`; `URLError.cancelled` and every other error pass through unchanged
  [`APIFailureMapping.swift:APIClient.send(_:failingWith:)`].
- `LostRace.attemptTwice` retries exactly once, only on `AppError.tryAgain`, after `sleep(delay)`; a second
  `tryAgain` propagates like any refusal [`LostRace.swift:LostRace.attemptTwice`].
- `WriteGate.run` wraps the work in `LostRace.attemptTwice(delay: tryAgainDelay)`, answers `true` on success; a
  cancellation (`AppError.isCancellation`) answers `false` silently; any other failure is first handed to `settling`
  (`{ _ in false }` for `run(_:_:)`), and `true` from it answers `true` with nothing logged or reported; otherwise the
  failure is logged (warning when `isExpected(appError)`, else error) and passed to `report`, then `false`. The busy
  flag stays at the call site [`WriteGate.swift:WriteGate.run(_:settling:_:)`, `WriteGate.swift:WriteGate.log(failure:of:)`].
- `LostAnswer.settle`: an error that is no `AppError`, or one neither `leavesOutcomeUnknown` nor `isWorthAnotherLook`,
  is `.unresolved` with nothing fetched or logged. Otherwise `refetch()` runs once (warning "outcome unknown ...;
  reading back" for an unknown outcome, info "Reading back after ..." for a refusal); a thrown refetch is `.unresolved`
  (warning unless cancelled), and so is a successful one under a caller cancelled meanwhile (`Task.isCancelled` checked
  after the read-back: nothing applied, nothing logged); otherwise the fresh state is passed to `apply` before anything
  else. A refusal is then
  `.didNotLand` whatever the intent (the backend's word that nothing changed is never read as landed); an unknown
  outcome is `.landed` when `intent(fresh)` is `true`, `.didNotLand` when `false`, `.unresolved` when `nil`
  [`LostAnswer.swift:LostAnswer.settle(_:despite:intent:)`].
- `CreateFlow.submit`: `send` runs through `LostRace.attemptTwice(delay: tryAgainDelay, sleep: sleep)` (one
  `TRY_AGAIN` repeat under the same client id); success is logged at info with `describe(created)`. A cancellation
  answers `nil` and reports nothing. `.createIdReused` runs `update` through the same repeat and answers its result
  (warning "was repeated with other details; updating it", info "updated with the latest details"); an update failure
  is logged at error and reported, never looked up (a cancellation answers `nil` quietly). Any other failure is logged at error; when
  `leavesOutcomeUnknown(appError)`, `lookup(clientID)` runs: an answer that `isOurs` is returned as landed (info), the
  `notFound` error means it did not land (debug), another lookup failure is a warning unless cancelled; a failure that is
  kept goes to `report` and `nil` is answered [`CreateFlow.swift:CreateFlow.submit(clientID:describing:send:update:)`,
  `CreateFlow.swift:CreateFlow.updated(_:_:)`, `CreateFlow.swift:CreateFlow.stored(_:despite:)`].
- `ProgressDataTask.run` honours a cancellation that lands before or after the data task starts (`TaskHandle.start`
  cancels instead of resuming when already cancelled); the KVO observation on `progress.fractionCompleted` is
  invalidated when the task completes; a completion with neither data nor error throws `URLError(.badServerResponse)`;
  each progress value is reported on the main actor in its own `Task`
  [`ProgressDataTask.swift:ProgressDataTask.run(_:in:progress:)`, `ProgressDataTask.swift:TaskHandle`].

## Side Effects

- `URLSession.dataTask(with:)`, `resume()` and `cancel()`, plus KVO on the task's `Progress`
  [`ProgressDataTask.swift:ProgressDataTask.run(_:in:progress:)`].
- Waits through the injected `Sleep` between the two attempts [`LostRace.swift:LostRace.attemptTwice`,
  `CreateFlow.swift:CreateFlow.attemptTwice(_:_:_:)`].
- Calls the caller's `refetch` and `apply` closures once per read-back [`LostAnswer.swift:LostAnswer.settle(_:despite:intent:)`],
  and the caller's `settling` closure once per non-cancelled failure [`WriteGate.swift:WriteGate.run(_:settling:_:)`].
- Calls the caller's `report` closure (the shared `ErrorCenter`) with the kept failure
  [`WriteGate.swift:WriteGate.run(_:settling:_:)`, `CreateFlow.swift:CreateFlow.submit(clientID:describing:send:update:)`].
- Logging under the caller's `category`: info "<what> lost a race; retrying once" [`LostRace.swift`]; warning or
  error "<what> failed: <error>" [`WriteGate.swift`]; warning "<what> outcome unknown (<error>); reading back", info
  "Reading back after <error> on <what>", warning "Could not read back after <what>: <error>", info "<what> landed
  despite <error>; nothing to report" [`LostAnswer.swift`]; info "<Noun> created <id> <tail>", error "Create failed for
  <noun> <clientID>", info "Create landed for <noun> <id> despite <error>", debug "No <noun> of ours under
  <clientID>", warning "Could not check whether <noun> <clientID> landed", warning "Create of <noun> <clientID> was
  repeated with other details; updating it", info "<Noun> <id> updated with the latest details", error "Update after a
  reused id failed for <noun> <clientID>: <error>" [`CreateFlow.swift`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Networking`:
  `SendFailingWithTests`, `LostRaceTests`, `WriteGateTests`, `LostAnswerTests`, `CreateFlowTests`; `BackendErrorCode`'s
  61 cases, their mappings and the eight Laurel codes without a case are pinned by `lilyTests/Errors/BackendErrorCodeTests`)
