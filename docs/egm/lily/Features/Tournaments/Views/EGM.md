# Tournaments: Views

Source: `lily/Features/Tournaments/Views/`

## Overview

The SwiftUI surfaces of the Tournaments feature, all `import SwiftUI` structs. Lists: the Explore carousel
(`TournamentCarousel`, `TournamentTile`), Discover (`DiscoverTournamentsView`), a group's segment
(`GroupTournamentsSegment`) and the shared card (`TournamentCard`, `TournamentCardList`, `TournamentStatusChip`), all
reading a `TournamentListViewModel`. The detail (redesigned 2026-11-27): `TournamentDetailView` keeps the wiring while
`TournamentDetailView+Content.swift` draws the blocks — the centered `DetailHeader` with `TournamentOutcomeLine`,
`TournamentFacts`, the People card, the About card, a results | matches picker over `TournamentResultsSegment`
(bracket, standings or matches) and the pinned `DetailActionBar` (chat and invite icons beside the
join/create-team/leave control) — hosting the edit, team-name, match, invite and report sheets and the confirmation
dialogs, around a `TournamentDetailViewModel`; who entered is the pushed `TournamentPeopleView` (an "Organised by"
row over `TournamentEntriesSegment`, 2026-11-28), and `TournamentMenu` keeps the organiser's Start, Edit, Cancel and Report
(`TournamentHeader`, `TournamentActionRow` and `TournamentParticipationControl` deleted that day). Writes: `MatchSheet`
with its pushed `MatchScheduleView`, and `TeamNameSheet`. The draft form `TournamentDraftForm<Model:
TournamentDraftEditing>` (+Schedule) recomposes its standalone section contents (`TournamentScheduleFields` and
`TournamentEntriesFields`, extracted 2026-11-10 for the creation wizard's pages; the create-only
`TournamentBasicsControls` and `TournamentWhoMayJoinControls` deleted 2026-11-11 — the wizard's cards own type,
format and who-may-join, and the edit shows the hosting group read-only through the shared `HostingGroupRow`) and
sits in `TournamentDraftSheet`, wrapped by `EditTournamentSheet` (creating walks the
wizard since slice 3, 2026-11-11; the create wrapper is gone). View models are in [`../ViewModels/EGM.md`](../ViewModels/EGM.md); layout math and
validation come from the models ([`../Models/EGM.md`](../Models/EGM.md): `BracketLayout`, `MatchScoreDraft`,
`MatchScheduleDraft`, `TeamNameIssue`). No file here branches on `LayoutMode` or `AppConfig.FeatureFlags`; wide
screens are handled with `readableColumn()`, `inReadableColumn()` and the bracket inset.

## Interface

- `[lily/Features/Tournaments/Views/TournamentCarousel.swift:TournamentCarousel]`: `TileCarousel` of
  `viewModel.visibleTournaments`, title `AppBranding.Tournaments.title`, "See all" to
  `DiscoverTournamentsDestination()`, identifiers `tournamentCarousel`, `tournamentsSeeAll`, `tournamentRow(id)`;
  `TournamentTile(tournament:fillsWidth:)` draws a `glassTile` with the type avatar (an `AvatarCircle` with the
  `.sport` tint, the maroon-to-accent fill and white glyph, since 2026-11-06; amber glass before), name and entries
  caption [`lily/Features/Tournaments/Views/TournamentCarousel.swift:TournamentTile`].
- `[lily/Features/Tournaments/Views/DiscoverTournamentsView.swift:DiscoverTournamentsView]`: `init(dependencies:
  AppDependencies)`, owns a `@State` `TournamentListViewModel` for `scope: .upcoming`; `ContentScreen` with a
  `TypeFilterButton` (`tournamentsTypeFilter`) in the toolbar, a `ProgressView` while `isInitialLoad`, else a
  refreshable `TournamentCardList` (the cards nearest first around a position, like the backend's ranked answer, and
  by start without one) or an `EmptyStateView` (`EmptyStateView.loadFailed` after a failed load, as in
  `GroupTournamentsSegment` and `TournamentDetailView`).
- `[lily/Features/Tournaments/Views/GroupTournamentsSegment.swift:GroupTournamentsSegment]`: `ListSegment(state:
  viewModel.listState)` around a single-column, unpadded `TournamentCardList`.
- `[lily/Features/Tournaments/Views/TournamentCard.swift:TournamentCard]`: `GlassCard` with `CardHeader` chips
  (`EventTypeChip`, `TournamentStatusChip`, `GroupBadge` when hosted), name, `PlaceLine`, `EntriesBar`;
  `TournamentCardList(tournaments:distance:horizontalPadding:singleColumn:)` is an `AdaptiveCardGrid` of
  `NavigationLink(value: tournament.destination)` stamped `tournamentRow(id)`.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView]`: `init(viewModel:
  TournamentDetailViewModel, dependencies: AppDependencies)`; `@State section: TournamentDetailSection = .results`,
  `presentedSheet: Sheet?` (`edit`, `teamName`, `invite`, `report`, `match(id:)`), `confirmation:
  TournamentConfirmation?`, `contentWidth`; renders `content(shown, isPreview:)` (`+Content.swift`, 2026-11-27) for
  `viewModel.shownDetail` or
  `emptyState` by `viewModel.state`; mounts the pinned bar in `safeAreaInset(edge: .bottom)` and registers
  `navigationDestination(for: TournamentPeopleDestination.self)`; toolbar `TournamentMenu` only while
  `permissions.showsMenu`; the shared
  `chatDestination(item: $viewModel.openedRoom, dependencies:)` (`lily/Features/Chat/Views/ChatDestinations.swift`,
  extracted in the round's review pass from the three identical pushes) pushes `ChatView` in place under the
  presenter's `\.tabBarHideToken`, released when the item binding clears (2026-11-19), so Back returns to the
  detail (the profile precedent, 2026-11-15). Wears `.hidesTabBarOnCompact()` after its inline title (2026-11-24,
  the detail-subpage rule): on a compact width the floating tab bar slides away with the push and back with the
  pop — the stack root's `animatesTabBar` owns the animation — and nothing changes on a regular width.
- `[lily/Features/Tournaments/Views/TournamentDetailView+Content.swift:TournamentDetailView.content]` (2026-11-27,
  replacing `TournamentHeader`): the detail's blocks as an extension — `header` (`DetailHeader` with the sport's
  mark, the name and format · status as the caption, over `TournamentOutcomeLine`), the Details section
  (`TournamentFacts`), `peopleSection` (the People card: one `PeopleSummaryRow` since 2026-11-28 — title
  `AppBranding.People.organisedBy(name:)` over the organiser's name through
  `Tombstone.displayName(tournament.organizerName, deleted: tournament.deleted)` (2026-11-07) with the tombstone as
  `titleMark` for a deleted account, caption `AppBranding.Tournaments.entries(_:of:teamSize:)` of the loaded
  roster's `registeredEntries.count` (the preview's own `entryCount` until the fetch answers), the stack the
  registered entries' names — identifier `peopleRow`, opening `TournamentPeopleDestination` only while
  `permissions.showsEntries && !isPreview`; the organiser's profile link lives in the pushed list now), `aboutSection` (the
  description card, only when one exists), `sectionPicker` (`tournamentSection`), `segment`, `loadingSlot`
  (`tournamentLoading` on an `.accessibilityElement(children: .contain)` container, so Try again keeps its own
  element; in the shared `TournamentSegmentSlot`), `bracketInset` and `actionBar`.
- `[lily/Features/Tournaments/Views/TournamentFacts.swift:TournamentFacts]` (its own file since 2026-11-27): start,
  registration close (only while `status == .registration`), place, the shared `HostedInLine` when hosted in a
  group, team size, `EntriesBar`. Same file: `TournamentOutcomeLine(tournament:, winnerName: String?)` — the winner
  line (`tournamentWinner`: a `Label` whose text is in the primary ink and whose trophy
  `DesignTokens.Symbols.winner` is in `Color.lilyAccent`) only for a completed tournament with a known `winnerName`,
  the `.secondary` cancelled notice for a cancelled one, nothing while it runs.
- `[lily/Features/Tournaments/Views/TournamentEntriesSegment.swift:TournamentEntriesSegment]`: `(viewModel, detail,
  onRemove: (TournamentEntry) -> Void)` (drawn by the pushed `TournamentPeopleView` since 2026-11-27) lists
  `detail.registeredEntries` as `EntryRow(entry:viewModel:teamSize:)`
  (each member's `PersonRow` takes the per-member `deleted` flag, so a deleted player shows the tombstone and opens
  no profile, 2026-11-07):
  a `PersonRow` for singles, a `GlassCard` team with seed chip, members, captain chip and a Join team `BusyButton`
  (`tournamentJoinTeam(id)`; spinnerless — `showsSpinner: false`, 2026-11-28); identifiers `entryRow(id)`,
  `participantRow(userId)`.
  `TournamentSegmentSlot(alignment:content:)` (same file) fixes one vertical footprint — hidden copies of the
  spinner, the empty entries line and the failed preview's Try again button (the tallest) under the content,
  `Spacing.xl` vertical padding — shared by the empty entries line and the detail's `loadingSlot`, so the content
  around it keeps its place when the fetch answers or the preview's load fails (2026-11-15).
- `[lily/Features/Tournaments/Views/TournamentPeopleView.swift:TournamentPeopleView]` (2026-11-27): `(viewModel:
  TournamentDetailViewModel)` plus the navigation value `TournamentPeopleDestination { tournamentId }` — the full
  entries list the People card's row pushes: an "Organised by" `DetailSection` (`AppBranding.People.organisedByRow`)
  of the organiser's `PersonRow` — identifier `participantRow(organizerUserId)`, `isSelf` by `viewModel.isSelf`,
  the tournament's `deleted` flag, so it opens the organiser's profile and never the caller's own row (2026-11-28,
  where the card's separate organiser link went) — over `TournamentEntriesSegment`, both reading
  `viewModel.shownDetail` in a
  `ContentScreen { ScrollView }` under the detail's margins, titled teams or players by `isTeam`, wearing
  `.hidesTabBarOnCompact()`; it owns the organiser's remove-entry `.confirmationDialog(item:)` (its `run` handles
  `.removeEntry` alone — cancel, leave and start stay with the detail) and reads the detail's own view model, so an
  entry made there is already in the list.
- `[lily/Features/Tournaments/Views/TournamentResultsSegment.swift:TournamentResultsSegment]`: `(showsMatches,
  detail, onSelect, bracketInset: CGFloat)` (no default) chooses `MatchList`, `BracketView` or `StandingsTable`, or an `EmptyStateView`
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
- `[lily/Features/Tournaments/Views/TournamentMenu.swift:TournamentMenu]`: `(viewModel, onStart, onEdit, onCancel,
  onReport)`, the toolbar `Menu` (`tournamentMore`, `tournamentStart`, `tournamentEdit`, `tournamentCancel`,
  `tournamentReport`), in its own file since 2026-11-27; its Open chat and Invite items left for the pinned bar
  (`tournament-action-chat` / `tournament-action-invite`; the menu-era `tournamentOpenChat` / `tournamentInvite`
  literals stay declared in `AccessibilityIdentifiers+Tournaments`, unused). The bar's `primaryControl`
  (`TournamentDetailView+Content.swift`, replacing `TournamentParticipationControl`) switches
  `viewModel.participation` into Join (`tournamentJoin`), Create team (`tournamentCreateTeam`), Leave
  (`tournamentLeave`, asking the leave confirmation), `DetailBarNotice`s or a disabled Full button (`tournamentJoin`);
  the Join and Full `BusyButton`s are spinnerless (`showsSpinner: false`, busy only guards the second tap,
  2026-11-28).
- `[lily/Features/Tournaments/Views/MatchSheet.swift:MatchSheet]`: `(viewModel, matchID, errorCenter)` in its own
  `NavigationStack`; `MatchCell`, a notice, two score `TextField`s (`matchScoreA`, `matchScoreB`; titled "0", the
  placeholder, with `.accessibilityLabel` the entry's name, so VoiceOver says whose score each takes), a
  `ValidationHint` while the draft is a disallowed draw, and the action
  buttons Record/Report, Confirm, Dispute, a walkover `Menu` (`matchWalkover`, `matchWalkoverWinner(id)`) and a
  Schedule link (`matchSchedule`) to `MatchScheduleView`.
- `[lily/Features/Tournaments/Views/MatchScheduleView.swift:MatchScheduleView]`: `(viewModel, match, onDone)` (`now`
  is read once in `init`)
  with a `@State MatchScheduleDraft` seeded from `MatchSchedule.proposal`; a `DatePicker` (`matchScheduleTime`),
  `PlaceFields` (`matchLocationName`, `matchPickOnMap`), Clear (`matchScheduleClear`) and a `DraftSubmitButton` Save
  (`matchScheduleSave`).
- `[lily/Features/Tournaments/Views/TeamNameSheet.swift:TeamNameSheet]`: `(viewModel, errorCenter)` with one
  `TextField` (`tournamentTeamName`), a `TeamNameIssue` footer, a `lilyToolbarTextButton()` Cancel and a
  `DraftSubmitButton` (`tournamentTeamSubmit`).
- `[lily/Features/Tournaments/Views/TournamentDraftForm.swift:TournamentDraftForm]`: `struct
  TournamentDraftForm<Model: TournamentDraftEditing>` with `@Bindable viewModel`; sections tournament (name
  `tournamentName`), where (`PlaceFields` with the optional detail line `tournamentLocationDetail` and
  `draft.placeChosen`, round 5 2026-11-12; `tournamentLocationName`,
  `createPickOnMap`; the footer adds `placeNotChosen`), when (start, deadline `tournamentDeadline`, registration close), entries (`tournamentTeamSize`,
  `tournamentMaxEntries`, draws `tournamentDraws`), who (the hosting group read-only through the shared
  `HostingGroupRow`, `createGroup`, shown only when `showsGroupRow`), details (the description over the shared
  `OptionalMarker`, 2026-11-13, the seventh round — wizard and edit form alike);
  the where, when, who and details sections are in
  `[lily/Features/Tournaments/Views/TournamentDraftForm+Schedule.swift:TournamentDraftForm.whenSection]`. The section
  contents the sections recompose are standalone `<Model: TournamentDraftEditing>` views:
  `[lily/Features/Tournaments/Views/TournamentScheduleFields.swift:TournamentScheduleFields]` (start, the deadline
  segments `tournamentDeadline`, the close date) and
  `[lily/Features/Tournaments/Views/TournamentEntriesFields.swift:TournamentEntriesFields]` (team size
  `tournamentTeamSize`, max entries `tournamentMaxEntries`, draws `tournamentDraws`, hidden for single elimination
  where `Tournament.permitsDraws` can never be true, 2026-11-11). The create-only `TournamentBasicsControls` and
  `TournamentWhoMayJoinControls` deleted 2026-11-11 with the `tournamentFormat` and `tournamentVisibility`
  identifiers: the wizard's cards own type, format and who-may-join; the
  sections keep the headers and the first-issue footers. `TournamentDraftSheet<Model>` wraps it in the shared `DraftSheet` (`tournamentFormCancel`, `tournamentSubmit`);
  `EditTournamentSheet` fixes the view-model type and the titles (the create wrapper left with slice 3, 2026-11-11).

## Invariants

- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.body]`: the preview and the
  loaded detail share one `content` branch keyed on `shownDetail`, so the scroll view keeps its offset when the fetch
  answers; the menu mounts only when `permissions.showsMenu`; the section picker and segment render only when
  `permissions.showsEntries`, and the preview shows `loadingSlot` in the segment's place.
- `[lily/Features/Tournaments/Views/TournamentDetailView+Content.swift:TournamentDetailView.actionBar]`
  (2026-11-27): the bar mounts only when `permissions.showsActionRow || participation != .hidden`; the chat icon
  shows under `canOpenChat` (`tournamentActionChat`, running `openChat()` in a `Task`), the invite icon under
  `canInvite` (`tournamentActionInvite`, presenting the invite sheet), both `lilyGlassIconButton()`; the organiser's
  notice (`Copy.organizingNotice`) draws only in the `.registrationClosed` case, by `role.isOrganizer` — everyone
  else reads the registration-closed notice there — and `.entered` reads "You're in" (`DetailBarNotice`s all).
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.run]`: cancel, leave, start and
  remove-entry run only from the confirmation dialog; callbacks set `confirmation`, never call the view model
  directly; the dialog button is destructive iff `confirmation.isDestructive`; after a start the section switches to
  results only when `hasMatches`.
- `[lily/Features/Tournaments/Views/TournamentDetailView+Content.swift:TournamentDetailView.segment]`: the bracket
  escapes the readable column only for `.results` with `drawsBracket` and matches, using `bracketInset =
  max(detailMargin, (contentWidth - readableWidth) / 2 + detailMargin)`; everything else is `inReadableColumn()`.
  `results(_:)` passes the computed `bracketInset` in both cases; only the bracket case reads it.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.sheet]`: every sheet receives
  `dependencies.errorCenter` and mounts its own popup through `lilyFormSheet(errorCenter:lockedWhile:)` (`MatchSheet`
  and `TeamNameSheet` locked while `viewModel.isBusy`, the shared `DraftSheet` while submitting); the detail view mounts none. The linked match opens its sheet once (`consumeLinkedMatch`), only when
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
  (tournament, where, when, entries, who, details); team size shows
  only when `allowsStructureChanges`; the draws picker only outside single elimination (a knockout never permits a
  draw, 2026-11-11); max entries, draws and the dates are disabled when `isLocked`
  (`[lily/Features/Tournaments/Views/TournamentEntriesFields.swift:TournamentEntriesFields]`,
  `[lily/Features/Tournaments/Views/TournamentScheduleFields.swift:TournamentScheduleFields]`); every footer stays
  in the form and shows the first matching
  `viewModel.issue(for:)`; deadline and draws are segmented pickers, team size and max entries are `Stepper`s; no toggles.
- `[lily/Features/Tournaments/Views/TournamentScheduleFields.swift:TournamentScheduleFields.body]`: start is
  bounded by `earliestStart...`, the close date by `...startsAt` and shown only when set; "at start" clears the
  deadline, "earlier" proposes `proposedDeadline()`.
  `[lily/Features/Tournaments/Views/TournamentDraftForm+Schedule.swift:TournamentDraftForm.whoSection]`: the group
  row is the shared `HostingGroupRow` (`lily/Features/Events/Views`), read-only on an edit (the group cannot
  change); the form offers no visibility choice since 2026-11-11 — who-may-join is fixed on create by the wizard's
  cards, and a group tournament follows its group's visibility.
- `[lily/Features/Tournaments/Views/TournamentMenu.swift:TournamentMenu]`: menu items are gated by `permissions`
  (`showsStart` with Start disabled unless `canStart` and subtitled by `startBlockedReason`, `canEdit`, `canCancel`,
  `canReport`); chat and invite are the bar's since 2026-11-27, and the primary control is chosen by `participation`
  alone.
  `[lily/Features/Tournaments/Views/TournamentEntriesSegment.swift:TournamentEntriesSegment]`: the Remove entry
  context item appears only when `permissions.canRemoveEntries` (its confirmation asked in `TournamentPeopleView`
  since 2026-11-27); Join team only when `viewModel.canJoin(entry)`.

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
  `consumeLinkedMatch()` (switching the picker to `.matches`); `.onChange(of: isGone)` calls `dismiss()`; the bar's
  Open chat runs
  `viewModel.openChat()`, whose `openedRoom` the view pushes through the shared `chatDestination(item:dependencies:)` (2026-11-15);
  the bar's Invite presents the invite sheet; the dialog runs `cancel()`, `leave()` or `start()` (the remove-entry
  question moved to `TournamentPeopleView`, 2026-11-27, whose dialog runs `removeEntry(_:)`).
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView.sheet]`: presenting a sheet
  builds view models through the container: `dependencies.makeEditTournamentViewModel(for:onChange:
  viewModel.accept)`, `makeTournamentInvitePeopleViewModel(for:)`, `makeReportViewModel(for:title:)`.
- `[lily/Features/Tournaments/Views/MatchSheet.swift:MatchSheet.scoreButton]`: `viewModel.report(_:scoreA:scoreB:)`,
  `confirm(_:)`, `dispute(_:)`, `walkover(_:winnerEntryID:)` (the last in a spawned `Task`), each dismissing on
  `true`; `MatchScheduleView` calls `viewModel.schedule(_:_:)` for Save and Clear and runs `onDone` on success.
- `[lily/Features/Tournaments/Views/TeamNameSheet.swift:TeamNameSheet.body]`: `viewModel.createTeam(named:onEntered:)`
  with `dismiss` as `onEntered`;
  focuses the field on appear. `EntryRow` calls `viewModel.joinTeam(entry)`; the bar's Join calls
  `viewModel.join()`.
- `[lily/Features/Tournaments/Views/TournamentDraftForm.swift:TournamentDraftForm]`: writes `viewModel.draft` fields
  through `@Bindable`, in the form and its standalone section views (`name`, `type`, `select(format:)`, `teamSize`, `maxEntries`, `allowsDraws`, `startsAt`,
  `registrationClosesAt`, `locationName`, `coordinate`, `group`, `visibility`, `description`); submission belongs to
  the shared `DraftSheet`.
- `[lily/Features/Tournaments/Views/TournamentDetailView.swift:TournamentDetailView]`: like every view in the
  directory, it performs no network calls, disk access, logging or timers of its own; all effects go through the view
  models above.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Tournaments`).
