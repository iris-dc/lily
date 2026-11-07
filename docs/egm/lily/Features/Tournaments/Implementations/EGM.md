# Tournaments: Implementations

Source: `lily/Features/Tournaments/Implementations/`

## Overview

The concrete types behind `TournamentRepository` ([`../Interfaces/EGM.md`](../Interfaces/EGM.md)) and the shared
`InviteRepository` (`lily/Features/Groups/Interfaces/InviteRepository.swift`). `RemoteTournamentRepository` and
`RemoteTournamentInviteRepository` build `APIRequest`s on `AppConfig.API.Paths` and call
`client.send(request, failingWith:)`, remapping three backend codes (one on the tournament routes, two on the invite
routes). `MockTournamentRepository` (split over `+Entries`
and `+Matches`) and `MockTournamentInviteRepository` reproduce the backend's refusals in memory over three
`MockTournamentFixtures` tournaments (Kickers Cup, Tuesday Table Tennis, Padel Open), store the caller as
`callerMarker` and swap in `identity.currentUserID` on the way out, and mirror every roster change into
`MockGroupRepository` rooms. The repository classes carry no isolation annotation (main-actor under the app's
default); the fixtures enum is `nonisolated`. The directory holds no retry or read-back code: the one `TRY_AGAIN`
repeat and the refetch after an unknown outcome live in the view models' `WriteGate` and `CreateFlow`
([`../ViewModels/EGM.md`](../ViewModels/EGM.md)). `AppConfig.FeatureFlags.tournaments` is not referenced here.

## Interface

- `[lily/Features/Tournaments/Implementations/RemoteTournamentRepository.swift:RemoteTournamentRepository]`:
  `final class RemoteTournamentRepository: TournamentRepository`, `init(client: any APIClient)`; implements all
  fifteen protocol requirements, each as one `send(request, failingWith:)`. Private: `send(_:failingWith:)`,
  `static listRequest(for:near:)` (switches on `.group(id)`, `.upcoming`, `.mine`), `static scopeItems(for:)`
  (`scope` query item from `TournamentScope.wireName`, none when nil).
- `[lily/Features/Tournaments/Implementations/RemoteTournamentInviteRepository.swift:RemoteTournamentInviteRepository]`:
  `final class RemoteTournamentInviteRepository: InviteRepository`, `init(client: any APIClient)`;
  `candidates(groupID:)` and `invite(groupID:userID:)` bind the protocol's `groupID` label to a tournament id.
  `private extension AppError { var asTournamentInviteRefusal }` remaps `.alreadyEntered` to
  `.inviteeAlreadyEntered` and `.insufficientRole` to `.cannotInviteToTournament`.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository]`:
  `final class MockTournamentRepository: TournamentRepository`,
  `init(groups: MockGroupRepository, identity: any IdentityProvider, logger: any Logging,
  deletedFixtures: Bool = false, now: @escaping () -> Date = { .now })` (the flag maps every seeded detail through
  `MockTournamentFixtures.stampingDeletedPlayer`, 2026-11-07).
  State: `details: [String: TournamentDetail]` (seeded from `MockTournamentFixtures.make(now:)`), `entrySequence`,
  `invitedTournamentIDs`, `drafts: [String: TournamentDraft]`. Internal helpers shared with the extensions: `readable(_:)`, `requireCaller()`,
  `organized(_:)`, `store(_:)`, `resolved(_:)` (detail and tournament overloads), `isInRoom(_:)`, `static isOpen(_:)`
  (in registration or in progress), `openOrganizedCount`, `noteInvitee(of:)`, `invited(_:)`. Implements
  `tournaments(in:near:)`, `tournament(id:)`, `create(_:)`, `update(id:_:)`, `cancel(id:)` here.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository+Entries.swift:MockTournamentRepository.join(id:teamName:)]`:
  `join`, `joinTeam`, `leave`, `removeEntry`; `openInRoomsCount`; private `requireRoomSlot(_:)`, `requireEnterable`,
  `counting(_:entries:departed:)`, `enter(_:logging:)`, `depart(_:userIDs:logging:)`, `nextEntryID(in:)`.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository+Matches.swift:MockTournamentRepository.start(id:)]`:
  `start`, `report`, `confirm`, `dispute`, `walkover`, `schedule`; private `runningMatch`, `requireOrganizer`,
  `requireSideOrOrganizer`, `requireOpen`, `requireReportedByTheOtherSide`, `standsByCaller`, `repeatsResult`,
  `repeatsConfirm`, `repeatsWalkover`, `replayed`, `reportedBySide`, `settle(_:in:)`.
- `[lily/Features/Tournaments/Implementations/MockTournamentInviteRepository.swift:MockTournamentInviteRepository]`:
  `final class MockTournamentInviteRepository: InviteRepository`,
  `init(groups:tournaments:identity:logger:now:)`; an in-memory `MockInviteLedger` and a `MockInviteCandidatePool`;
  `candidates(groupID:)`, `invite(groupID:userID:)`; private `requireInviteRights(in:)`, `peopleIn(_:)` and
  `candidates(for:in:)` (the pool minus the tournament's people, built once per call by both public methods).
- `[lily/Features/Tournaments/Implementations/MockTournamentFixtures.swift:MockTournamentFixtures]`:
  `nonisolated enum` with `kickersCupID`, `tableTennisID` (`ids` also lists `padelOpenID`, declared in `+PadelOpen`),
  `callerMarker = "mock-caller"`,
  `make(now:) -> [TournamentDetail]`, `kickersCup(now:organizerUserID:organizerName:)`,
  `deletedPlayer` ("Noor") and `stampingDeletedPlayer(_:)` (2026-11-07, `-mock-deleted-user`: in Tuesday Table Tennis
  the deleted player's member snapshot and their solo entry's name become the placeholder with the per-member
  `deleted: true` — the deletion job's stamps-pass shape; everything else untouched),
  `entryID(tournamentID:index:)`, `playerCount(of:)`, `coordinate(offset:)` (through `Coordinate.aroundMockCenter`,
  `lily/Core/Location/Models/Coordinate+MockOffset.swift`), the roster constants (`kickersTeams`,
  `tableTennisPlayers`) and the table-tennis script (`tableTennisResults`, `tableTennisReport`,
  `tableTennisDispute`, `tableTennisScheduledMatchID`, `tableTennisLocation`).
- `[lily/Features/Tournaments/Implementations/MockTournamentFixtures+PadelOpen.swift:MockTournamentFixtures.padelOpen(now:)]`:
  the `+PadelOpen` extension holds `padelOpenID`, `padelOpenPlayers` (Noor, Aiko, Sam, Tom), the private `padelOpenStartsInDays`
  (12) and `padelOpen(now:) -> TournamentDetail`.
- `[lily/Features/Tournaments/Implementations/MockTournamentFixtures+Rooms.swift:MockTournamentFixtures.rooms(now:)]`:
  `rooms(now:) -> [SportGroup]`, `room(for:organizerName:memberCount:membership:lastMessageId:lastMessageAt:)`,
  `roster(for:now:) -> [GroupMember]`; private `callerMembership(in:)`.
- `[lily/Features/Tournaments/Implementations/MockTournamentFixtures.swift:MockTournamentFixtures.make(now:)]`: the
  three fixtures: Kickers Cup (football, single elimination, teams of 5, 4 of 8 entries, caller organises, hosted by
  the Kickers group, starts in 9 days, deadline in 7); Tuesday Table Tennis (round robin, `.inProgress`, 6 players
  including the caller, Marta organises, three results recorded, one report by Jonas, one dispute by Noor, match
  `r03p002` scheduled `AppConfig.Inbox.mockReminderLead` ahead); Padel Open (round robin, `.private`, Noor organises
  and plays, 4 of 8, starts in 12 days, no group). Every date is `now` offset by a day or hour count times
  `TimeInterval.day`/`.hour` (`lily/Core/System/TimeInterval+Units.swift`).

## Invariants

- `[lily/Features/Tournaments/Implementations/RemoteTournamentRepository.swift:RemoteTournamentRepository.send(_:failingWith:)]`:
  exactly one `client.send` per call; `AppError.membershipLimitReached` is rethrown as
  `AppError.tournamentMembershipLimit` on every tournament route; everything else propagates unchanged.
- `[lily/Features/Tournaments/Implementations/RemoteTournamentRepository.swift:RemoteTournamentRepository.create(_:)]`:
  a draft without a coordinate fails before the network (`CreateTournamentPayload(draft:)` nil throws
  `.tournamentCreationFailed`; `UpdateTournamentPayload(draft:)` nil throws `.tournamentUpdateFailed`).
- `[lily/Features/Tournaments/Implementations/RemoteTournamentRepository.swift:RemoteTournamentRepository.listRequest(for:near:)]`:
  the position goes out only for `.upcoming`; `.mine` sends `scope=mine` without it; `.group` uses the group route
  with no query. `leave` answers nil on an empty body (`OptionalBody<TournamentEntry>`), the entry having emptied.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository.readable(_:)]`:
  read rule: an unknown id throws `.tournamentNotFound`; a non-public tournament is readable only when the caller is
  in its room (`isInRoom`), a member of the hosting group, or in `invitedTournamentIDs`; otherwise the same
  `.tournamentNotFound`. Reads stay anonymous; `requireCaller()` throws `.sessionExpired` on every write except
  `create`.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository.organized(_:)]`:
  `update`, `cancel`, `removeEntry` and `start` check caller, then readability, then
  `tournament.isOrganized(by: MockTournamentFixtures.callerMarker)` (`.notOrganizer`); every organiser test in the mock
  (`openOrganizedCount`, `isInRoom`, `leave`, the match writes' `requireOrganizer(of:)` and `requireSideOrOrganizer`,
  the rooms' `callerMembership` and `roster`) is that one model rule over the marker.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository.create(_:)]`:
  idempotent by `draft.clientId` (an existing id replays the stored tournament when the draft equals the stored one,
  `drafts`, and is `.createIdReused` when it differs; `update` stores the new draft); refusals in order: no coordinate or
  `maxEntries` below `AppConfig.Tournaments.minEntries(for:)` (`.tournamentCreationFailed`), a group that is unknown
  or neither public nor joined (`.groupNotFound`, `hostingGroup(for:)`), then the organiser's cap: `openOrganizedCount`
  (stored tournaments organised by `callerMarker` whose status `isOpen`) at `AppConfig.Tournaments.maxOrganizedOpen`
  refuses with `.tournamentLimit`, never a replay, which answered first; then `GroupAccess.canCreateEvents` false
  (`.insufficientRole`), the order Laurel judges them in (`groupFor`, `requireOrganizerSlot`, the role inside the
  write's transaction).
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository.tournament(id:)]`:
  the read rule, then a caller with no user (`identity.currentUserID == nil`) gets the root alone (`entries`, `matches`
  and `standings` empty, `myEntryId` nil), as Laurel answers a guest; a signed-in caller gets the resolved detail.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository.update(id:_:)]`:
  after registration, `startsAt`, `registrationClosesAt`, `resolvedAllowsDraws` and `maxEntries` must be unchanged
  (`.tournamentLocked`); then the format floor (`.tournamentUpdateFailed`); then `maxEntries >= entryCount`
  (`.capacityTooLow`). `cancel` refuses `.completed` (`.tournamentLocked`) and replays `.cancelled` unchanged.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository.tournaments(in:near:)]`:
  `.upcoming` is `isListed && startsAt >= now()`, nearest first then by start (by start alone without a position);
  `.mine` ranks in-progress, then registration, then the rest (finished by last change descending, others by start);
  `.group` drops cancelled and sorts by start.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository.resolved(_:)]`:
  stored rows hold `callerMarker` for the caller; every answer swaps it for `identity.currentUserID` and recomputes
  `myEntryId` from the roster (nil when signed out), so one fixture set serves any mock sign-in.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository+Entries.swift:MockTournamentRepository.join(id:teamName:)]`:
  refusal order: `.sessionExpired`, read rule, for a team a `TeamNameIssue` (`.tournamentActionFailed`; Laurel
  validates the body before counting rooms), the caller's cap (`requireRoomSlot`: a caller already in this room is
  let through; otherwise `openInRoomsCount`, the stored tournaments the caller is in whose status `isOpen`, at
  `AppConfig.Tournaments.maxPerUser` refuses with `.tournamentMembershipLimit`), `.registrationClosed`,
  `.alreadyEntered`, `.tournamentFull`. `joinTeam`: the
  caller's cap, `.entryNotFound`, `.alreadyEntered` (same entry), `.teamFull`, then the tournament's own refusals. `leave`: only the player, their captain or the organiser
  (`.insufficientRole`), only during registration (`.registrationClosed`), target must be in the entry
  (`.entryNotFound`).
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository+Entries.swift:MockTournamentRepository.counting(_:entries:departed:)]`:
  `channelEpoch` increments only when someone other than the organiser departs; new entry ids are
  `entryID(tournamentID:, index: 100 + entrySequence)` and the new seed is the current maximum plus one.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository+Matches.swift:MockTournamentRepository.start(id:)]`:
  a start on `.inProgress` replays the detail; any other non-registration status is `.tournamentLocked`;
  `!canStart` is `.notEnoughEntries`.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository+Matches.swift:MockTournamentRepository.runningMatch(_:_:)]`:
  match writes check `.sessionExpired`, the read rule, `status != .inProgress` (`.matchNotReady`), the match id
  (`.matchNotFound`), then side-or-organiser (`.notInMatch`) for report, confirm and dispute, or organiser
  (`.notOrganizer`) for walkover and schedule.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository+Matches.swift:MockTournamentRepository.report(id:matchID:scoreA:scoreB:)]`:
  scores must sit in `AppConfig.Tournaments.scoreRange` before any lookup (`.tournamentActionFailed`); an equal
  score without `permitsDraws` is `.drawNotAllowed`; `!isReadyForResult` is `.matchNotReady`. The organiser records;
  a player answering the other side's identical reported score confirms instead of re-reporting.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository+Matches.swift:MockTournamentRepository.standsByCaller(_:as:)]`:
  a result, confirmation or walkover that already stands by the caller's hand answers the current detail with no
  write; a dispute is never a repeat. `confirm` and `dispute` need `.reported` by the other side (`.matchNotReady`);
  a walkover's winner must be in the match (`.tournamentActionFailed`); `schedule` refuses a decided match
  (`.matchNotReady`).
- `[lily/Features/Tournaments/Implementations/MockTournamentInviteRepository.swift:MockTournamentInviteRepository.requireInviteRights(in:)]`:
  `.sessionExpired`, the read rule, not in the room (`.cannotInviteToTournament`), registration closed
  (`.registrationClosed`); inviting an entrant, the organiser or oneself is `.inviteeAlreadyEntered`; the
  tournament's own room is excluded from the candidate pool.
- `[lily/Features/Tournaments/Implementations/MockTournamentFixtures+Rooms.swift:MockTournamentFixtures.room(for:organizerName:memberCount:membership:lastMessageId:lastMessageAt:)]`:
  a room shares the tournament's id, has `maxMembers = maxEntries * teamSize + 1`, `kind: .tournament`, and members
  can neither create events nor invite; the caller owns the Kickers Cup room, is a member of the table-tennis room
  and has no membership in the Padel Open room, which is `.private` and unreadable until `noteInvitee(of:)` admits
  the caller.

## Side Effects

- `RemoteTournamentRepository` routes (`AppConfig.API.Paths`, literal paths as read in `lily/Config`), each cited
  `[lily/Features/Tournaments/Implementations/RemoteTournamentRepository.swift:RemoteTournamentRepository.<method>]`:

| Method | Request | Body | Answer | Fallback `AppError` |
| --- | --- | --- | --- | --- |
| `tournaments(in:near:)` | GET `/api/tournaments?scope=upcoming[&lat&lon]`, `?scope=mine`, or `/api/groups/{id}/tournaments` | none | `Page<Tournament>` | `.tournamentsUnavailable` |
| `tournament(id:)` | GET `/api/tournaments/{id}` | none | `TournamentDetail` | `.tournamentsUnavailable` |
| `create(_:)` | POST `/api/tournaments` | `CreateTournamentPayload` | `TournamentDetail` | `.tournamentCreationFailed` |
| `update(id:_:)` | PUT `/api/tournaments/{id}` | `UpdateTournamentPayload` | `TournamentDetail` | `.tournamentUpdateFailed` |
| `join(id:teamName:)` | POST `/api/tournaments/{id}/entries` | `CreateEntryPayload` | `TournamentEntry` | `.tournamentActionFailed` |
| `joinTeam(id:entryID:)` | POST `.../entries/{entryID}/members` | none | `TournamentEntry` | `.tournamentActionFailed` |
| `leave(id:entryID:userID:)` | DELETE `.../entries/{entryID}/members/{userID}` | none | `OptionalBody<TournamentEntry>` | `.tournamentActionFailed` |
| `removeEntry(id:entryID:)` | DELETE `.../entries/{entryID}` | none | `NoContent` | `.tournamentActionFailed` |
| `start(id:)` | POST `/api/tournaments/{id}/start` | none | `TournamentDetail` | `.tournamentActionFailed` |
| `report(...)` | PUT `.../matches/{matchID}/result` | `MatchResultPayload` | `TournamentDetail` | `.tournamentActionFailed` |
| `confirm(...)` | POST `.../matches/{matchID}/confirm` | none | `TournamentDetail` | `.tournamentActionFailed` |
| `dispute(...)` | POST `.../matches/{matchID}/dispute` | none | `TournamentDetail` | `.tournamentActionFailed` |
| `walkover(...)` | POST `.../matches/{matchID}/walkover` | `WalkoverPayload` | `TournamentDetail` | `.tournamentActionFailed` |
| `schedule(...)` | PUT `.../matches/{matchID}/schedule` | `MatchSchedulePayload` | `TournamentMatch` | `.tournamentActionFailed` |
| `cancel(id:)` | POST `/api/tournaments/{id}/cancel` | none | `TournamentDetail` | `.tournamentActionFailed` |

- `[lily/Features/Tournaments/Implementations/RemoteTournamentInviteRepository.swift:RemoteTournamentInviteRepository.candidates(groupID:)]`:
  GET `/api/tournaments/{id}/invitees` (`Page<InviteCandidate>`) and POST `/api/tournaments/{id}/invites` with
  `SendInvitePayload(userId:)` (`SentInvite`); both fall back to `.inviteUnavailable`.
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository.create(_:)]`:
  every mock write mutates `details` through `store(_:)` and mirrors the room: `groups.registerRoom` on create,
  `groups.syncRoom` after update, join, leave and removal, `groups.admitToRoom` on join, `groups.leaveRoom` per
  departing user; `noteInvitee(of:)` mutates `invitedTournamentIDs`; `join` increments `entrySequence`; `create` and
  `update` write `drafts` (a repeated create with other details is `.createIdReused`).
- `[lily/Features/Tournaments/Implementations/MockTournamentRepository.swift:MockTournamentRepository.tournaments(in:near:)]`:
  logging under `.tournaments`: reads at debug ("Mock tournaments served for scope ...", "Mock tournament ...
  served"), every write at info (created or replayed, updated, cancelled, joined, left, removed, started, result,
  confirmed, dispute, walkover, scheduled or cleared, repeated writes, and "completed" when a result ends the
  tournament).
- `[lily/Features/Tournaments/Implementations/MockTournamentInviteRepository.swift:MockTournamentInviteRepository.invite(groupID:userID:)]`:
  records the invite in the in-memory `MockInviteLedger` (nothing reaches an inbox); the "Mock invite candidates
  served" debug line comes from `candidates(groupID:)` alone, an invite builds its list through the private helper
  without it.
- `[lily/Features/Tournaments/Implementations/MockTournamentFixtures.swift:MockTournamentFixtures]`: pure
  construction; `+Rooms` reads `MockChatFixtures.newestMessageID(for:)` and `MockGroupFixtures` ids. No `Task`,
  sleep, timer, UserDefaults or disk access anywhere in the directory.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Tournaments`; the guest
  root in `MockTournamentRepositoryTests.aGuestReadsTheRootAlone`, the two caps in `MockTournamentRefusalsTests+Caps`).
