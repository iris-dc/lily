# Tournaments: Views

Source: `lily/Features/Tournaments/Views/`

## Overview

The SwiftUI surfaces of the Tournaments feature, all `import SwiftUI` structs. Lists: the Explore carousel
(`TournamentCarousel`, `TournamentTile`), Discover (`DiscoverTournamentsView`), a group's segment
(`GroupTournamentsSegment`) and the shared card (`TournamentCard`, `TournamentCardList`, `TournamentStatusChip`), all
reading a `TournamentListViewModel`. The detail: `TournamentDetailView` composes `TournamentHeader`,
`TournamentFacts`, a segmented section picker, `TournamentEntriesSegment`, `TournamentResultsSegment` (bracket,
standings or matches), `TournamentParticipationControl` and the `TournamentMenu`, hosting the edit, team-name, match,
invite and report sheets and the confirmation dialogs, around a `TournamentDetailViewModel`. Writes: `MatchSheet`
with its pushed `MatchScheduleView`, and `TeamNameSheet`. The draft form `TournamentDraftForm<Model:
TournamentDraftEditing>` (+Schedule) sits in `TournamentDraftSheet`, wrapped by `CreateTournamentSheet` and
`EditTournamentSheet`. View models are in [`../ViewModels/EGM.md`](../ViewModels/EGM.md); layout math and
validation come from the models ([`../Models/EGM.md`](../Models/EGM.md): `BracketLayout`, `MatchScoreDraft`,
`MatchScheduleDraft`, `TeamNameIssue`). No file here branches on `LayoutMode` or `AppConfig.FeatureFlags`; wide
screens are handled with `readableColumn()`, `inReadableColumn()` and the bracket inset.

## Interface

- `[lily/Features/Tournaments/Views/TournamentCarousel.swift:TournamentCarousel]`: `TileCarousel` of
  `viewModel.visibleTournaments`, title `AppBranding.Tournaments.title`, "See all" to
  `DiscoverTournamentsDestination()`, identifiers `tournamentCarousel`, `tournamentsSeeAll`, `tournamentRow(id)`;
  `TournamentTile(tournament:fillsWidth:)` draws a `glassTile` with the type avatar, name and entries caption.
- `[lily/Features/Tournaments/Views/DiscoverTournamentsView.swift:DiscoverTournamentsView]`: `init(dependencies:
  AppDependencies)`, owns a `@State` `TournamentListViewModel` for `scope: .upcoming`; `ContentScreen` with a
  `TypeFilterButton` (`tournamentsTypeFilter`) in the toolbar, a `ProgressView` while `isInitialLoad`, else a
  refreshable `TournamentCardList` or an `EmptyStateView`.
- `[lily/Features/Tournaments/Views/GroupTournamentsSegment.swift:GroupTournamentsSegment]`: `ListSegment(state:
  viewModel.listState)` around a single-column, unpadded `TournamentCardList`.
- `[lily/Features/Tournaments/Views/TournamentCard.swift:TournamentCard]`: `GlassCard` with `CardHeader` chips
  (`EventTypeChip`, `TournamentStatusChip`, `GroupBadge` when hosted), name, `PlaceLine`, `EntriesBar`;
  `TournamentCardList(tournaments:distance:horizontalPadding:singleColumn:)` is an `AdaptiveCardGrid` of
  `NavigationLink(value: tournament.destination)` stamped `tournamentRow(id)`.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView]`: `init(viewModel:
  TournamentDetailViewModel, dependencies: AppDependencies)`; `@State section: TournamentDetailSection`,
  `presentedSheet: DetailSheet?` (`edit`, `teamName`, `invite`, `report`, `match(id:)`), `confirmation:
  TournamentConfirmation?`, `contentWidth`; renders `content(shown, isPreview:)` for `viewModel.shownDetail` or
  `emptyState` by `viewModel.state`; toolbar `TournamentMenu`; `sectionPicker` (`tournamentSection`),
  `loadingSlot` (`tournamentLoading`), `bracketInset`.
- `[lily/Features/Tournaments/Views/TournamentHeader.swift:TournamentHeader]`: `(tournament, organizerProfile:
  UserProfileDestination?, winnerName: String?)`: chips (type, format, status), `OwnerTitleBlock`
  (`tournamentOrganizer`), the winner line (`tournamentWinner`: a `Label` whose text is in the primary ink and whose
  trophy `DesignTokens.Symbols.winner` is in `Color.lilyAccent`) or cancelled notice, `HostedInLine`.
  `TournamentFacts(tournament:)`: start, registration close, place, team size, `EntriesBar`.
- `[lily/Features/Tournaments/Views/TournamentEntriesSegment.swift:TournamentEntriesSegment]`: `(viewModel, detail,
  onRemove: (TournamentEntry) -> Void)` lists `detail.registeredEntries` as `EntryRow(entry:viewModel:teamSize:)`:
  a `PersonRow` for singles, a `GlassCard` team with seed chip, members, captain chip and a Join team `BusyButton`
  (`tournamentJoinTeam(id)`); identifiers `entryRow(id)`, `participantRow(userId)`.
- `[lily/Features/Tournaments/Views/TournamentResultsSegment.swift:TournamentResultsSegment]`: `(showsMatches,
  detail, onSelect, bracketInset)` chooses `MatchList`, `BracketView` or `StandingsTable`, or an `EmptyStateView`
  (`AppBranding.Tournaments.notStarted`) with no matches.
- `[lily/Features/Tournaments/Views/BracketView.swift:BracketView]`: `(detail, onSelect, contentInset)`, a horizontal
  scroll of `BracketLayout.columns(of:)` with `RoundTitle` and fixed-height `MatchButton`s (`tournamentBracket`).
  `[lily/Features/Tournaments/Views/MatchList.swift:MatchList]`: the same columns stacked vertically with details
  (`tournamentMatches`). `[lily/Features/Tournaments/Views/StandingsTable.swift:StandingsTable]`: rank, name,
  played, won, drawn (when `permitsDraws`), lost, difference, points (`tournamentStandings`, `standing(entryId)`).
- `[lily/Features/Tournaments/Views/MatchCell.swift:MatchCell]`: `(match, detail, showsDetails)` two sides with
  scores, seeds, the accent dispute flag, and a `.secondary` caption of status ("Disputed" too), time and place;
  `MatchButton` wraps it (`match(id)`); `RoundTitle`
  draws `BracketLayout.roundTitle`.
- `[lily/Features/Tournaments/Views/TournamentParticipationControl.swift:TournamentParticipationControl]`:
  `(viewModel, onCreateTeam, onLeave)` switches `viewModel.participation` into Join (`tournamentJoin`), Create team
  (`tournamentCreateTeam`), Leave (`tournamentLeave`), notices or a disabled Full button. `TournamentMenu(viewModel,
  onOpenChat, onInvite, onStart, onEdit, onCancel, onReport)` is the toolbar `Menu` (`tournamentMore`,
  `tournamentOpenChat`, `tournamentInvite`, `tournamentStart`, `tournamentEdit`, `tournamentCancel`,
  `tournamentReport`).
- `[lily/Features/Tournaments/Views/MatchSheet.swift:MatchSheet]`: `(viewModel, matchID, errorCenter)` in its own
  `NavigationStack`; `MatchCell`, a notice, two score `TextField`s (`matchScoreA`, `matchScoreB`; titled "0", the
  placeholder, with `.accessibilityLabel` the entry's name, so VoiceOver says whose score each takes), a
  `ValidationHint` while the draft is a disallowed draw, and the action
  buttons Record/Report, Confirm, Dispute, a walkover `Menu` (`matchWalkover`, `matchWalkoverWinner(id)`) and a
  Schedule link (`matchSchedule`) to `MatchScheduleView`.
- `[lily/Features/Tournaments/Views/MatchScheduleView.swift:MatchScheduleView]`: `(viewModel, match, now, onDone)`
  with a `@State MatchScheduleDraft` seeded from `MatchSchedule.proposal`; a `DatePicker` (`matchScheduleTime`),
  `PlaceFields` (`matchLocationName`, `matchPickOnMap`), Clear (`matchScheduleClear`) and a `DraftSubmitButton` Save
  (`matchScheduleSave`).
- `[lily/Features/Tournaments/Views/TeamNameSheet.swift:TeamNameSheet]`: `(viewModel, errorCenter)` with one
  `TextField` (`tournamentTeamName`), a `TeamNameIssue` footer, a `lilyToolbarTextButton()` Cancel and a
  `DraftSubmitButton` (`tournamentTeamSubmit`).
- `[lily/Features/Tournaments/Views/TournamentDraftForm.swift:TournamentDraftForm]`: `struct
  TournamentDraftForm<Model: TournamentDraftEditing>` with `@Bindable viewModel`; sections tournament (name
  `tournamentName`, `EventTypeChips`, format `tournamentFormat`), where (`PlaceFields`, `tournamentLocationName`,
  `createPickOnMap`), when (start, deadline `tournamentDeadline`, registration close), entries (`tournamentTeamSize`,
  `tournamentMaxEntries`, draws `tournamentDraws`), who (`createGroup`, visibility `tournamentVisibility`), details;
  the where, when, who and details sections and their identifiers are in
  `[lily/Features/Tournaments/Views/TournamentDraftForm+Schedule.swift:TournamentDraftForm.whenSection]`.
  `TournamentDraftSheet<Model>` wraps it in the shared `DraftSheet` (`tournamentFormCancel`, `tournamentSubmit`);
  `CreateTournamentSheet` and `EditTournamentSheet` fix the view-model type and the titles.

## Invariants

- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.body]`: the preview and the
  loaded detail share one `content` branch keyed on `shownDetail`, so the scroll view keeps its offset when the fetch
  answers; the menu mounts only when `permissions.showsMenu`; the section picker and segment render only when
  `permissions.showsEntries`, and the preview shows `loadingSlot` in the segment's place.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.run]`: cancel, leave, start and
  remove-entry run only from the confirmation dialog; callbacks set `confirmation`, never call the view model
  directly; the dialog button is destructive iff `confirmation.isDestructive`; after a start the section switches to
  results only when `hasMatches`.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.segment]`: the bracket escapes the
  readable column only for `.results` with `drawsBracket` and matches, using `bracketInset = max(detailMargin,
  (contentWidth - readableWidth) / 2 + detailMargin)`; everything else is `inReadableColumn()`.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.sheet]`: every sheet receives
  `dependencies.errorCenter` and mounts its own `.errorPopup` (`MatchSheet`, `TeamNameSheet`, the shared
  `DraftSheet`); the detail view mounts none. The linked match opens its sheet once (`consumeLinkedMatch`), only when
  no sheet is up; `isGone` dismisses the screen while a first-load `.notFound` keeps the empty state.
- `[lily/Features/Tournaments/Views/DiscoverTournamentsView.swift:DiscoverTournamentsView.content]`: spinner while
  `isInitialLoad`; empty-state precedence is load failure, then an active `typeFilter`, then the plain empty copy.
- `[lily/Features/Tournaments/Views/BracketView.swift:BracketView.body]`: `.accessibilityElement(children:
  .contain)` precedes every container identifier (`tournamentBracket`, `tournamentMatches`, `tournamentStandings`,
  the team `entryRow`); a later round's cell is framed to `BracketLayout.slotHeight` so it spans its feeders.
- `[lily/Features/Tournaments/Views/StandingsTable.swift:StandingsTable.row]`: rows keep `detail.standings` order;
  the Drawn column appears only when `permitsDraws`; the caller's own entry is highlighted.
  `[lily/Features/Tournaments/Views/MatchCell.swift:MatchCell.side]`: the dispute flag draws only on side A for an
  open dispute and is the one accent in the cell besides the border, the "Disputed" caption reading `.secondary` with
  the rest of `details`; the winner is semibold, the loser faded; a bye reads `Copy.bye`; the caller's match gets the
  accent border.
- `[lily/Features/Tournaments/Views/MatchSheet.swift:MatchSheet.actionButtons]`: buttons follow
  `viewModel.actions(for:)`: Record or Report (exclusive), Confirm, Dispute, walkover, Schedule; Report/Record is
  disabled unless `scores.canSubmit(permitsDraws:)`, with a draws-not-allowed `ValidationHint` in the caption font;
  the notice is dispute, then
  awaiting the other side, then "reported by"; dismissal is disabled while `isBusy`; a walkover offers only present
  sides.
- `[lily/Features/Tournaments/Views/MatchScheduleView.swift:MatchScheduleView.body]`: Save is enabled only when
  `draft.isValid`; Clear appears only when `match.hasSchedule`; the date picker's range starts at `draft.earliest`.
  `[lily/Features/Tournaments/Views/TeamNameSheet.swift:TeamNameSheet.body]`: Create is enabled only when
  `TeamNameIssue.issue(in:) == nil`; the sheet dismisses through `createTeam(named:onEntered:)`'s `onEntered`, as soon
  as the team exists and before the reminders are offered, and as a fallback once `tournament.hasEntered`.
- `[lily/Features/Tournaments/Views/TournamentDraftForm.swift:TournamentDraftForm.body]`: section order is fixed
  (tournament, where, when, entries, who, details); type, format and team size show only when
  `allowsStructureChanges`; max entries, draws and the dates are disabled when `isLocked`; the format is written only
  through `draft.select(format:)`; every footer shows the first matching `viewModel.issue(for:)`; format, deadline,
  draws and visibility are segmented pickers (the format over `TournamentFormat.known`), the type is `EventTypeChips`, team size and max entries are `Stepper`s;
  no toggles.
- `[lily/Features/Tournaments/Views/TournamentDraftForm+Schedule.swift:TournamentDraftForm.whenSection]`: start is
  bounded by `earliestStart...`, the close date by `...startsAt` and shown only when set; "at start" clears the
  deadline, "earlier" proposes `proposedDeadline()`; the visibility picker shows only for a standalone tournament
  with structure changes allowed; the group row is read-only for a locked group or with no eligible group.
- `[lily/Features/Tournaments/Views/TournamentParticipationControl.swift:TournamentMenu]`: menu items are gated by
  `permissions` (`canOpenChat`, `canInvite`, `showsStart` with Start disabled unless `canStart` and subtitled by
  `startBlockedReason`, `canEdit`, `canCancel`, `canReport`); the control is chosen by `participation` alone.
  `[lily/Features/Tournaments/Views/TournamentEntriesSegment.swift:TournamentEntriesSegment]`: the Remove entry
  context item appears only when `permissions.canRemoveEntries`; Join team only when `viewModel.canJoin(entry)`.

## Side Effects

- `[lily/Features/Tournaments/Views/DiscoverTournamentsView.swift:DiscoverTournamentsView.body]`: `.task(id:
  dependencies.tournamentChanges.version) { await viewModel.loadIfStaleNearTheUser() }`; pull to refresh calls
  `viewModel.load()`; the filter button writes `viewModel.typeFilter`.
- `[lily/Features/Tournaments/Views/TournamentCard.swift:TournamentCardList.body]`: navigation by value:
  `NavigationLink(value: tournament.destination)` and `TileLink` push `TournamentDestination`; "See all" pushes
  `DiscoverTournamentsDestination`.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.body]`: `.task(id:
  dependencies.tournamentChanges.version) { await viewModel.loadIfNeeded() }`; `.refreshable` and both Try again
  buttons call `viewModel.load()`; `.onChange(of: linkedMatchToShow)` presents the match sheet and calls
  `consumeLinkedMatch()`; `.onChange(of: isGone)` calls `dismiss()`; the menu's Open chat runs
  `viewModel.openChat()`; the dialog runs `cancel()`, `leave()`, `start()` or `removeEntry(_:)`.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.sheet]`: presenting a sheet
  builds view models through the container: `dependencies.makeEditTournamentViewModel(for:onChange:
  viewModel.accept)`, `makeTournamentInvitePeopleViewModel(for:)`, `makeReportViewModel(for:title:)`.
- `[lily/Features/Tournaments/Views/MatchSheet.swift:MatchSheet.scoreButton]`: `viewModel.report(_:scoreA:scoreB:)`,
  `confirm(_:)`, `dispute(_:)`, `walkover(_:winnerEntryID:)` (the last in a spawned `Task`), each dismissing on
  `true`; `MatchScheduleView` calls `viewModel.schedule(_:_:)` for Save and Clear and runs `onDone` on success.
- `[lily/Features/Tournaments/Views/TeamNameSheet.swift:TeamNameSheet.body]`: `viewModel.createTeam(named:onEntered:)`
  with `dismiss` as `onEntered`;
  focuses the field on appear. `EntryRow` calls `viewModel.joinTeam(entry)`; `TournamentParticipationControl` calls
  `viewModel.join()`.
- `[lily/Features/Tournaments/Views/TournamentDraftForm.swift:TournamentDraftForm]`: writes `viewModel.draft` fields
  through `@Bindable` (`name`, `type`, `select(format:)`, `teamSize`, `maxEntries`, `allowsDraws`, `startsAt`,
  `registrationClosesAt`, `locationName`, `coordinate`, `group`, `visibility`, `description`); submission belongs to
  the shared `DraftSheet`.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView]`: like every view in the
  directory, it performs no network calls, disk access, logging or timers of its own; all effects go through the view
  models above.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Tournaments`).
