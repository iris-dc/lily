# Tournaments: Models

Source: `lily/Features/Tournaments/Models/`

## Overview

The pure value types of the Tournaments feature: the wire-shaped records Laurel sends (`Tournament`, `TournamentDetail`,
`TournamentEntry`, `TournamentMatch`, `MatchSchedule`, `TournamentStanding`, `TournamentChange`), the string-backed
status enums, the `Encodable` request bodies, the organiser's `TournamentDraft` with its on-device validation, and the
decision logic layered over them: who may do what (`TournamentRole`, `TournamentParticipation`,
`TournamentPermissions`, `MatchActions`), whether a lost write already stands (`MatchWrite`), round-robin ranking
(`RoundRobinStandings`), bracket geometry (`BracketLayout`) and the pairing generator the mock uses
(`TournamentSchedule`). Every type is `nonisolated` and `Sendable`; the wire records' mutable fields are `private(set)`
and change only through copy-returning functions, while the three drafts (`TournamentDraft`, `MatchScoreDraft`,
`MatchScheduleDraft`) and `TournamentSchedule.Pairing` expose plain `var`s for the form bindings and the generator;
nothing here performs I/O or touches shared state. Limits come from
`AppConfig.Tournaments` (`lily/Config/AppConfig+Tournaments.swift`) and `AppConfig.Events`, copy from
`AppBranding.Tournaments`. Consumers: [`../ViewModels/EGM.md`](../ViewModels/EGM.md),
[`../Views/EGM.md`](../Views/EGM.md), [`../Implementations/EGM.md`](../Implementations/EGM.md).

## Interface

- `[lily/Features/Tournaments/Models/Tournament.swift:Tournament]`: `Identifiable, Hashable, Codable, Sendable`.
  Immutable `id`, `type: EventType`, `format`, `visibility: GroupVisibility`, `teamSize`, `organizerName`,
  `group: EventGroupRef?`, `createdAt`; `private(set)` `name`, `description?`, `status`, `maxEntries`, `entryCount`,
  `allowsDraws`, `startsAt`, `registrationClosesAt?`, `location: EventLocation`, `organizerUserId`, `channelEpoch`,
  `myEntryId?`, `winnerEntryId?`, `startedAt?`, `completedAt?`, `updatedAt?`. Computed `isTeam`, `isPublic`,
  `hasEntered`, `isFull`, `isListed`, `fillRatio`, `isNearlyFull`, `canStart`, `permitsDraws`, `entriesText`,
  `destination`; `isOrganized(by:)`, `isRegistrationOpen(now:)`, `distance(from:)`; copy-returning
  `updatingEntries(...)`, `replacingOrganizer(...)`, `updating(with:at:)`, `starting(at:)`, `completing(...)`,
  `cancelling(at:)`.
- `[lily/Features/Tournaments/Models/Tournament.swift:TournamentScope]`: `enum { upcoming, mine, group(id:) }` with
  `wireName: String?` and `snapshotList`. `TournamentDestination(id, name, matchID?, preview: Tournament?)` and the
  empty marker `DiscoverTournamentsDestination` are the feature's navigation values.
- `[lily/Features/Tournaments/Models/TournamentDetail.swift:TournamentDetail]`: `tournament`, `entries`, `matches`,
  `standings` (all `private(set)`); `registeredEntries`, `entry(id:)`, `match(id:)`, `entryName(_:)`, `isMine(_:)`,
  `entry(containing:)`, `opponent(in:of:)`; copy-returning `replacing(...)` variants, `starting(at:)`,
  `settling(_:at:)`.
- `[lily/Features/Tournaments/Models/TournamentDetailSection.swift:TournamentDetailSection]`: `enum { entries,
  results, matches }`, `title(for:)`, `symbolName`.
  `[lily/Features/Tournaments/Models/TournamentChange.swift:TournamentChange]`: `(tournamentId, status, entryCount,
  channelEpoch, updatedAt?)`, the room channel's `tournament_changed` payload.
- `[lily/Features/Tournaments/Models/TournamentEntry.swift:TournamentEntry]`: `(id, tournamentId, name,
  captainUserId, members: [EntryMember(userId, displayName)], seed, status: EntryStatus, createdAt)`; `memberCount`,
  `isRegistered`, `isFull(teamSize:)`, `contains(userID:)`, `isCaptain(_:)`; copy-returning `adding(_:)`,
  `removing(userID:)`, `replacingUser(_:with:)`.
- `[lily/Features/Tournaments/Models/TournamentFormat.swift:TournamentFormat]`: `String` enums `TournamentFormat`
  (`single_elimination`, `round_robin`; `displayName`, `entriesRange`, `minimumEntriesToStart`, `drawsBracket`),
  `TournamentStatus` (`registration`, `in_progress`, `completed`, `cancelled`; `isOver`), `EntryStatus` (`registered`,
  `withdrawn`), `MatchStatus` (`pending`, `scheduled`, `reported`, `confirmed`, `walkover`, `bye`; `isDecided`,
  `isOpen`), `MatchSlot` (`a`, `b`).
- `[lily/Features/Tournaments/Models/TournamentMatch.swift:TournamentMatch]`: immutable `id`, `tournamentId`, `round`,
  `position`, `nextMatchId?`, `nextSlot?`; `private(set)` sides, `status`, scores, `winnerEntryId`, `isDisputed`,
  `scheduledAt`, `location`, reporter and confirmer stamps. `hasBothSides`, `isDecided`, `isOpenDispute`,
  `isReadyForResult`, `hasSchedule`, `outcome(for:) -> MatchOutcome { won, lost, drew, undecided }`,
  `contains(entryID:)`; copy-returning `placing`, `reporting`, `recording`, `confirming`, `disputing`, `walkover`,
  `scheduling`, `replacingUser`. Same file: `MatchSchedule(scheduledAt?, location?)` with `isEmpty` and
  `proposal(for:in:now:calendar:)`; `TournamentStanding` (rank, played, won, drawn, lost, scored, conceded, points).
- `[lily/Features/Tournaments/Models/TournamentDraft.swift:TournamentDraft]`: `Equatable, Sendable`, not Codable:
  `clientId`, `name`, `description`, `type`, `format`, `teamSize`, `maxEntries`, `allowsDraws: Bool?`, `startsAt`,
  `registrationClosesAt?`, `locationName`, `coordinate?`, `group?`, `visibility`; `init(startsAt:clientId:)`,
  `init(editing:)`; nested `Rules` and `Issue` (eleven cases); `issues(now:rules:)`, `isValid(now:rules:)`,
  `select(format:)`, `earliestStart(now:rules:)`, `proposedDeadline(before:now:)`, `makeTournament(...)`;
  `EventType.allowsDrawsByDefault`.
- `[lily/Features/Tournaments/Models/TournamentPayloads.swift:CreateTournamentPayload]`: `Encodable`-only bodies
  `CreateTournamentPayload` and `UpdateTournamentPayload` (failable `init?(draft:)`), `CreateEntryPayload(name?)`,
  `MatchResultPayload(scoreA, scoreB)`, `WalkoverPayload(winnerEntryId)`, `MatchSchedulePayload(init(schedule:))`.
- `[lily/Features/Tournaments/Models/TournamentParticipation.swift:TournamentRole]`: `enum { guest, organizer,
  entrant(entryID:), outsider }` from `(tournament, userID)`; `TournamentParticipation { hidden, join, createTeam,
  leave, entered, registrationClosed, full }` from `(tournament, userID, now)`.
- `[lily/Features/Tournaments/Models/TournamentPermissions.swift:TournamentPermissions]`: `canEdit`, `canCancel`,
  `canRemoveEntries`, `canOpenChat`, `canInvite`, `canReport`, `showsEntries`, `showsStart`, `canStart`,
  `canJoinTeams`, `startBlockedReason?`, `organizerProfile: UserProfileDestination?`, `showsMenu`, `static none`;
  `init(tournament:userID:now:chatEnabled:)`.
- `[lily/Features/Tournaments/Models/MatchActions.swift:MatchActions]`: `canReport`, `canConfirm`, `canDispute`,
  `canRecord`, `canWalkover`, `canSchedule`, `awaitsOtherSide`; `none`, `isEmpty`, `takesScore`;
  `init(detail:match:userID:)`.
- `[lily/Features/Tournaments/Models/MatchScoreDraft.swift:MatchScoreDraft]`: two score strings, `parsed`,
  `isDisallowedDraw(permitsDraws:)`, `canSubmit(permitsDraws:)`.
  `[lily/Features/Tournaments/Models/MatchScheduleDraft.swift:MatchScheduleDraft]`: `scheduledAt`, `locationName`,
  `coordinate?`, `earliest`; `isValid`, `location(venue:)`, `schedule(venue:)`.
- `[lily/Features/Tournaments/Models/MatchWrite.swift:MatchWrite]`: `enum { result(scoreA:scoreB:), confirmation,
  dispute, walkover(winnerEntryID:), schedule(MatchSchedule) }` with `landed(on:callerID:) -> Bool`.
- `[lily/Features/Tournaments/Models/RoundRobinStandings.swift:RoundRobinStandings]`: `compute(entries:matches:) ->
  [TournamentStanding]`. `[lily/Features/Tournaments/Models/BracketLayout.swift:BracketLayout]`: `columns(of:)`,
  `slotHeight(round:cellHeight:spacing:)`, `roundTitle(round:of:format:)`. Both are caseless namespaces.
- `[lily/Features/Tournaments/Models/TeamNameIssue.swift:TeamNameIssue]`: `enum { tooShort, tooLong }`, `issue(in:)`.
  `[lily/Features/Tournaments/Models/TournamentConfirmation.swift:TournamentConfirmation]`: `enum { cancel, leave,
  start, removeEntry(TournamentEntry) }` with `title(name:)`, `message(entries:)`, `buttonTitle`, `isDestructive`.
- `[lily/Features/Tournaments/Models/TournamentSchedule.swift:TournamentSchedule]`: namespace with nested `Pairing`;
  `pairings(format:seeds:)`, `matchID(round:position:)`.

## Invariants

- `[lily/Features/Tournaments/Models/Tournament.swift:Tournament]`: Codable is synthesized for every wire type
  (`Tournament`, `TournamentDetail`, `TournamentChange`, `TournamentEntry`, `TournamentMatch`, `MatchSchedule`,
  `TournamentStanding`, `TournamentSchedule.Pairing`): no `CodingKeys`, no hand-written `init(from:)`, so property
  names are the wire keys, non-optional keys must be present and nil optionals are omitted.
- `[lily/Features/Tournaments/Models/TournamentFormat.swift:TournamentFormat]`: none of the five status enums has an
  `unknown` case; only the listed raw values decode.
- `[lily/Features/Tournaments/Models/Tournament.swift:Tournament.isRegistrationOpen(now:)]`: `status == .registration
  && (registrationClosesAt.map { now < $0 } ?? true)`; `isFull = entryCount >= maxEntries`; `isListed = isPublic &&
  status == .registration`; `canStart = status == .registration && entryCount >= format.minimumEntriesToStart`;
  `permitsDraws = allowsDraws && format == .roundRobin`; `fillRatio` clamps to 1 and never divides by zero.
- `[lily/Features/Tournaments/Models/Tournament.swift:Tournament.starting(at:)]`: `starting`, `completing`,
  `cancelling` and `updating(with:at:)` stamp `updatedAt` and never validate the prior status (refusals stay with the
  repositories); `updating` copies only name, description, dates, place (keeping the old coordinate when the draft has
  none), `allowsDraws` and `maxEntries`. `TournamentScope.group` has no `wireName`.
- `[lily/Features/Tournaments/Models/TournamentDetail.swift:TournamentDetail.settling(_:at:)]`: unchanged when no
  held match has the id; otherwise swaps the match, advances a decided winner into `nextMatchId`/`nextSlot`,
  recomputes standings (round robin only) and completes the tournament only when every match is decided (`champion`:
  the final's winner or the table leader). `registeredEntries` filters `isRegistered` and sorts by `seed` on every
  access.
- `[lily/Features/Tournaments/Models/TournamentDraft.swift:TournamentDraft.issues]`: `nameIssues + placeIssues +
  scheduleIssues + entriesIssues + detailIssues`, in form order. Name `3...60` (`AppConfig.Tournaments.nameLength`),
  description `<= 1000`, place name `<= 120` (`AppConfig.Events.Creation.locationNameMaxLength`), team size `1...11`,
  `maxEntries` within `format.entriesRange` (`2...64` single elimination, `3...12` round robin) and `>=
  rules.minimumEntries`; lengths are `wireLength` (UTF-16). The schedule is judged only when `rules.judgesSchedule`; a
  deadline must be strictly before the start.
- `[lily/Features/Tournaments/Models/TournamentDraft.swift:TournamentDraft.Rules]`: `creation` uses
  `AppConfig.Events.Creation.minimumLeadTime` and `minimumEntries = 2`; `editing(entryCount:isLocked:)` uses the
  editing lead time, `minimumEntries = max(2, entryCount)` and `judgesSchedule = !isLocked`; `entriesRange(for:)` is
  never inverted; `select(format:)` clamps `maxEntries`; `proposedDeadline = max(now, startsAt -
  AppConfig.Tournaments.defaultDeadlineLead)`.
- `[lily/Features/Tournaments/Models/TournamentDraft.swift:TournamentDraft.clientId]`: a fresh lower-cased UUID on
  create, the tournament id on edit; sent as `clientTournamentId`, the create's idempotency key. `effectiveVisibility
  = group?.visibility ?? visibility`; `resolvedAllowsDraws = allowsDraws ?? type.allowsDrawsByDefault` (true for
  football, basketball, volleyball).
- `[lily/Features/Tournaments/Models/TournamentPayloads.swift:CreateTournamentPayload.init?(draft:)]`: both failable
  inits return nil without a coordinate; `visibility` is sent only for a standalone tournament; an update never
  carries `type`, `format`, `teamSize`, `group` or `visibility`; a `MatchSchedulePayload` with both fields nil clears
  the schedule.
- `[lily/Features/Tournaments/Models/TournamentEntry.swift:TournamentEntry.removing(userID:)]`: nil when no member
  remains; when the captain is removed, the captaincy passes to the first remaining member in join order.
- `[lily/Features/Tournaments/Models/TournamentMatch.swift:TournamentMatch.settled]`: a settled score sets
  `.confirmed`, the confirmer stamps, and `winnerEntryId` nil on a draw; `reporting` only overwrites the report;
  `confirming` is a no-op without both scores; `disputing()` clears the report, returns to `.scheduled`/`.pending` and
  sets `isDisputed`, which nothing resets; `walkover` leaves scores nil; `scheduling` recomputes the status only while
  open. `isReadyForResult = hasBothSides && (status.isOpen || status == .reported)`.
- `[lily/Features/Tournaments/Models/TournamentParticipation.swift:TournamentRole.init]`: nil user is `.guest`; the
  organiser wins over an own entry. `TournamentParticipation` precedence: hidden, leave or entered (by registration
  open), registrationClosed, full, createTeam or join (by `isTeam`).
- `[lily/Features/Tournaments/Models/TournamentPermissions.swift:TournamentPermissions.init]`: `canEdit = canCancel =
  organiser && !isOver`; `canRemoveEntries = organiser && .registration`; `canOpenChat = chatEnabled && involved`;
  `canInvite = involved && registration open`; `canReport = signed in && !organiser`; `canStart = showsStart &&
  tournament.canStart`, else `startBlockedReason` from `AppBranding.Tournaments.startNeeds`; `organizerProfile` only
  for a signed-in non-organiser; `showsMenu` ignores `showsStart`, `canRemoveEntries`, `canJoinTeams`.
- `[lily/Features/Tournaments/Models/MatchActions.swift:MatchActions.init]`: `.none` unless the tournament is
  `.inProgress` and the user is known; an entrant acts only on a match containing their entry; the organiser may
  confirm a reported match, record or give a walkover while `isReadyForResult`, and schedule while undecided; a side
  may report while ready and the other side has not, confirm or dispute the other side's report, and
  `awaitsOtherSide` after its own.
- `[lily/Features/Tournaments/Models/MatchScoreDraft.swift:MatchScoreDraft.parsed]`: both scores must parse and sit
  in `AppConfig.Tournaments.scoreRange` (`0...999`); a draw is refused unless `permitsDraws`.
  `MatchScheduleDraft.isValid` checks only the place name's `wireLength <= 120`; `earliest = min(now, proposed)` so a
  past schedule stays selectable.
- `[lily/Features/Tournaments/Models/MatchWrite.swift:MatchWrite.landed(on:callerID:)]`: a write already stands when
  the match shows its scores with the caller as reporter or confirmer, is confirmed by the caller, is an open dispute,
  is a walkover to that winner confirmed by the caller, or carries that exact schedule.
- `[lily/Features/Tournaments/Models/RoundRobinStandings.swift:RoundRobinStandings.compute]`: 3 points a win, 1 a
  draw; only decided matches with both sides count; a walkover is a 0-0 win; order is points, difference, scored, then
  seed; ranks are 1-based; entries are keyed with `Dictionary(uniqueKeysWithValues:)`, so duplicate ids trap.
- `[lily/Features/Tournaments/Models/BracketLayout.swift:BracketLayout]`: columns are rounds ascending, positions
  ascending; `slotHeight` spans `2^(round-1)` feeders; single-elimination titles are final, semi-finals,
  quarter-finals, then "round of 2^(d+1)"; other formats use numbered rounds.
- `[lily/Features/Tournaments/Models/TournamentSchedule.swift:TournamentSchedule.pairings]`: `[]` below two seeds;
  ids are `r%02dp%03d`; single elimination fills the smallest power-of-two bracket in `bracketOrder` (seed 1 meets
  seed N, byes fall to top seeds and advance at once); round robin is the circle method, no `nextMatchId`.
- `[lily/Features/Tournaments/Models/TeamNameIssue.swift:TeamNameIssue.issue(in:)]`: trimmed `wireLength` against
  `AppConfig.Tournaments.teamNameLength` (`2...40`). `TournamentConfirmation`: every case but `.start` is destructive
  and only `.start` has a message. `TournamentDetailSection.title(for:)` reads teams or players by `isTeam`, bracket
  or standings by `format.drawsBracket`.

## Side Effects

- None. Every function is pure; the in-place mutations are `TournamentDraft.select(format:)` and the drafts' plain
  `var` fields, always on the caller's copy.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Tournaments`).
