# Create Views: Tournament pages

Source: `lily/Features/Create/Views/Tournament/`

## Overview

The tournament flow's nine one-idea pages (slice 3 of the creation-wizard plan, 2026-11-11), in the event pages'
language: custom glass layouts over the aurora, composed from the tournament form's extracted section views and the
shared components, rendered inside `WizardStepScaffold` and bound through `TournamentDraftEditing`; the wizard is
read through `CreationWizardControlling`. The walk is Name / Type / Format / Schedule / Hosting group (conditional
on the opening exactly like the event flow's) / Place / Entries / Who may join / Details. Every tournament form
field identifier is byte-identical to the edit form's.

## Interface

- `TournamentNamePage<Model>` (`lily/Features/Create/Views/Tournament/TournamentNamePage.swift:TournamentNamePage`):
  the name capsule (`tournament-name`) with the keyboard up on entry; owns `nameTooShort`/`nameTooLong`.
- `TournamentTypePage<Model>` (`TournamentTypePage.swift:TournamentTypePage`): the shared `WizardTypePicker` (the
  third design round, 2026-11-11) — a search field (`create-type-search`) over the compact grid, one card per
  `EventType.known` (reusing `createEventType(_:)`), auto-advancing; a tournament's type is non-optional and fixed
  once created. No issues.
- `TournamentFormatPage<Model>` (`TournamentFormatPage.swift:TournamentFormatPage`): one card per
  `TournamentFormat.known` (`create-format-<wireName>`; the bracket symbol for a knockout, the standings symbol for
  round robin), picking through `draft.select(format:)` (which pulls the entries under the new cap) and
  auto-advancing. No issues.
- `TournamentSchedulePage<Model>` (`TournamentSchedulePage.swift:TournamentSchedulePage`): the shared
  `TournamentScheduleFields` (start, deadline segments `tournament-deadline`, close date) in one `GlassCard`; the
  caption explains the deadline; owns `startsAtTooSoon`/`registrationClosesAfterStart`.
- `TournamentGroupPage<Model>` (`TournamentGroupPage.swift:TournamentGroupPage`): on the walk exactly when the
  opening offers the choice (`CreationSteps.offersGroupChoice`); the shared `HostingGroupRow` behind an outer label
  (`create-group`, `labelsHidden()`), a `ProgressView` placeholder until `viewModel.hasLoadedGroups`, and the
  no-eligible-groups explanation under the card; the caption says what hosting in a group means. No issues.
- `TournamentPlacePage<Model>` (`TournamentPlacePage.swift:TournamentPlacePage`): the shared `PlaceNameField`
  (`tournament-location-name`) with its suggestions card, the optional detail line (`PlaceDetailField`,
  `tournament-location-detail`; 2026-11-12), then the shared `WizardPlaceMapRow`
  (`create-pick-on-map`, the id the tournament form already shared with the event's) pushing the path element
  `CreationStep.tournamentMap`. Owns the four place issues — `placeNotChosen` among them since round 5
  (2026-11-12): a tournament needs both halves and the typed name really chosen (the caption says so,
  `tournamentPlaceCaption`, 2026-11-11).
- `TournamentEntriesPage<Model>` (`TournamentEntriesPage.swift:TournamentEntriesPage`): the shared
  `TournamentEntriesFields` (team size `tournament-team-size`, cap `tournament-max-entries`, draws
  `tournament-draws`, hidden for single elimination where draws are never permitted, 2026-11-11) in one
  `GlassCard` with the caption explaining the rules; owns
  `teamSizeOutOfRange`/`maxEntriesOutOfRange`/`maxEntriesBelowEntries`.
- `TournamentWhoPage<Model>` (`TournamentWhoPage.swift:TournamentWhoPage`): for a standalone draft
  (`draft.group == nil`) one auto-advancing `WizardChoiceCard` per visibility (`create-visibility-*`) with the
  chosen side's footer under them; once a group is chosen (locked or picked) a read-only `GlassCard` shows
  `draft.effectiveVisibility` with the follows-group line (`AppBranding.Create.tournamentFollowsGroup`) under it.
  No issues.
- `TournamentDetailsPage<Model>` (`TournamentDetailsPage.swift:TournamentDetailsPage`): the final step — the
  multiline description capsule over the shared `OptionalMarker` (2026-11-11); the scaffold's bottom bar carries the create button (`tournament-submit`), gated
  by the whole-draft rule. Owns `descriptionTooLong`.

## Invariants

- The issue partition renders where it gates: each page shows only `wizard.blockingMessage(on:)` for its own step
  (the tournament copy takes the live draft's format for the entries limits); the final gate stays authoritative in
  the scaffold.
- Focus and keyboard: the typing pages pass their focused field as the scaffold's `scrollTarget`, mark it with
  `.id`, and clear the focus when the wizard's path changes, so a pop-return lands keyboard-down; the name page
  focuses on entry.
- Step captions belong to the scaffold (`WizardStepCopy.swift`); no new copy and no literals — every string reads
  through `AppBranding.Tournaments.Create`, `AppBranding.Groups`, `AppBranding.Events.Create` or `AppBranding.Create`.
- A map spot goes through `TournamentDraft.pickSpot` (the user's choice, `PlacePickingDraft`); a suggestion through
  `draft.apply(_:)` (a proposal); the format only ever writes through `draft.select(format:)`.

## Side Effects

- None beyond the bindings into the view model's draft; the geocoder is only reached through the view model's
  `placeSuggestions(for:)` seam.

## Verification

- Run: `./scripts/ci.sh build` (zero `/lily/` warnings); the model and partition behind the pages:
  `./scripts/ci.sh unit` (`lilyTests/Create/CreationStepsTournamentTests.swift`,
  `CreationWizardModelKindsTests.swift`; the preparation seams in
  `lilyTests/Tournaments/CreateTournamentPreparationTests.swift`). The rendered pass ran with the third design
  round's capture set; the tournament walk is pinned on a simulator by
  `LilyTournamentTests.testCreatingATournamentFromExploreShowsItOnHome`.
