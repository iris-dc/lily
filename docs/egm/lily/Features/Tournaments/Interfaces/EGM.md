# Tournaments: Interfaces

Source: `lily/Features/Tournaments/Interfaces/`

## Overview

The protocol boundary of the Tournaments feature. `TournamentRepository` is the contract every caller depends on for
tournament reads and writes (lists, detail, create and edit, entries and teams, the match lifecycle, start and
cancel); its concrete types live in [`../Implementations/EGM.md`](../Implementations/EGM.md) (`RemoteTournamentRepository`
over the API client, `MockTournamentRepository` for the simulator and UI tests). `TournamentDraftEditing` refines the
shared sheet contract `DraftSubmitting` (`lily/Core/UI/Interfaces/DraftSubmitting.swift`) with what the tournament
create and edit form needs from its view model, pinning the issue type to `TournamentDraft.Issue`
(`lily/Features/Tournaments/Models/TournamentDraft.swift`). No concrete types, state or I/O live here. Both protocols
are plain declarations under the app target's default `@MainActor` isolation.

## Interface

- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository]`: `protocol TournamentRepository`,
  no inherited protocols or associated types; every requirement is `async throws`:

```swift
func tournaments(in scope: TournamentScope, near position: Coordinate?) async throws -> [Tournament]
func tournament(id: String) async throws -> TournamentDetail
func create(_ draft: TournamentDraft) async throws -> TournamentDetail
func update(id: String, _ draft: TournamentDraft) async throws -> TournamentDetail
func join(id: String, teamName: String?) async throws -> TournamentEntry
func joinTeam(id: String, entryID: String) async throws -> TournamentEntry
func leave(id: String, entryID: String, userID: String) async throws -> TournamentEntry?
func removeEntry(id: String, entryID: String) async throws
func start(id: String) async throws -> TournamentDetail
func report(id: String, matchID: String, scoreA: Int, scoreB: Int) async throws -> TournamentDetail
func confirm(id: String, matchID: String) async throws -> TournamentDetail
func dispute(id: String, matchID: String) async throws -> TournamentDetail
func walkover(id: String, matchID: String, winnerEntryID: String) async throws -> TournamentDetail
func schedule(id: String, matchID: String, _ schedule: MatchSchedule) async throws -> TournamentMatch
func cancel(id: String) async throws -> TournamentDetail
```

- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository.schedule]`: the only write
  that answers a `TournamentMatch`; every other write answers a `TournamentDetail` or an entry.
- `[lily/Features/Tournaments/Interfaces/TournamentDraftEditing.swift:TournamentDraftEditing]`:
  `protocol TournamentDraftEditing: DraftSubmitting where Issue == TournamentDraft.Issue`. It inherits from
  `DraftSubmitting: AnyObject, Observable` (`associatedtype Issue: Equatable`, `issues`, `isSubmitting`, `canSubmit`,
  `isDone`, `prepare() async`, `submit() async`, and the default `issue(for:)` helper) and adds the form's
  requirements:

```swift
var draft: TournamentDraft { get set }        // the only read-write requirement
var earliestStart: Date { get }               // the earliest start the date picker offers
func proposedDeadline() -> Date
var entriesRange: ClosedRange<Int> { get }    // the range the entries stepper offers
var isLocked: Bool { get }
var allowsStructureChanges: Bool { get }
var lockedGroup: EventGroupRef? { get }       // the group shown read-only when the form may not change it
var showsGroupRow: Bool { get }
var eligibleGroups: [EventGroupRef] { get }
var explainsNoEligibleGroups: Bool { get }
```

- `[lily/Features/Tournaments/Interfaces/TournamentDraftEditing.swift:extension TournamentDraftEditing]`: default
  implementations `eligibleGroups` returning `[]` and `explainsNoEligibleGroups` returning `false`, so only a create
  view model overrides them.
- `[lily/Features/Tournaments/Models/TournamentDraft.swift:TournamentDraft.Issue]`: the pinned issue type,
  `enum Issue: Hashable, Sendable` with cases `nameTooShort`, `nameTooLong`, `locationNameMissing`,
  `locationNameTooLong`, `coordinateMissing`, `startsAtTooSoon`, `registrationClosesAfterStart`,
  `teamSizeOutOfRange`, `maxEntriesOutOfRange`, `maxEntriesBelowEntries`, `descriptionTooLong`.
- Conformers in this feature: `RemoteTournamentRepository` and `MockTournamentRepository`
  ([`../Implementations/EGM.md`](../Implementations/EGM.md)); `CreateTournamentViewModel` and
  `EditTournamentViewModel` ([`../ViewModels/EGM.md`](../ViewModels/EGM.md)); the generic consumer is
  `TournamentDraftForm<Model: TournamentDraftEditing>` ([`../Views/EGM.md`](../Views/EGM.md)).

## Invariants

The protocols carry their rules as doc comments on the requirements; implementations and mocks are expected to
honour them.

- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository]`: failures arrive as
  `AppError`; every write answers what the backend now holds.
- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository.tournaments]`: scope
  semantics: `.upcoming` is public tournaments in registration, ranked around the position (`lat`/`lon`, or a
  signed-in caller's home area) with distance among the signals, by start without one (since 2026-10-07, corrected
  2026-11-02); `.mine` is every tournament whose room the caller is in; `.group` is a group's tournaments in all
  statuses but cancelled.
- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository.tournament]`: throws
  `AppError.tournamentNotFound` both when the tournament is gone and for a private tournament the caller may not see.
- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository.create]`: idempotent by
  `TournamentDraft.clientId`: repeating a create with the same id answers the same tournament; the caller becomes the
  organiser.
- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository.update]`: after the start
  only name, description and place change.
- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository.join]`: `teamName` is ignored
  when the caller enters alone; otherwise the caller becomes captain of a team with that name.
- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository.leave]`: returns `nil` when
  the entry emptied and is gone; the caller may be the player, their captain or the organiser.
- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository.removeEntry]`:
  organiser-only, and only while registration is open.
- `[lily/Features/Tournaments/Interfaces/TournamentRepository.swift:TournamentRepository.start]`: organiser-only; a
  replay on an already started tournament answers its current detail rather than failing.
- `[lily/Features/Tournaments/Interfaces/TournamentDraftEditing.swift:TournamentDraftEditing]`: the
  `where Issue == TournamentDraft.Issue` clause fixes the inherited associated type, so every conformer's `issues`
  is `[TournamentDraft.Issue]`; the protocol is class-bound and observable only through `DraftSubmitting`.
- `[lily/Features/Tournaments/Interfaces/TournamentDraftEditing.swift:TournamentDraftEditing.proposedDeadline]`: the
  proposed deadline lands a day before the start and never before the view model's now.
- `[lily/Features/Tournaments/Interfaces/TournamentDraftEditing.swift:TournamentDraftEditing.entriesRange]`: an
  edit's range floor is the number of entries already in.
- `[lily/Features/Tournaments/Interfaces/TournamentDraftEditing.swift:TournamentDraftEditing.isLocked]`: after the
  start the schedule, the draws and the entries are fixed; only the name, description and place change.
- `[lily/Features/Tournaments/Interfaces/TournamentDraftEditing.swift:TournamentDraftEditing.allowsStructureChanges]`:
  type, format, team size and visibility are fixed once the tournament exists; an edit never offers them.
- `[lily/Features/Tournaments/Interfaces/TournamentDraftEditing.swift:extension TournamentDraftEditing]`: only a
  create fills `eligibleGroups`; an edit offers no group choice because the tournament's group cannot change.

## Side Effects

- None. This directory declares protocols and two pure default implementations; all I/O belongs to the conformers.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Tournaments`).
