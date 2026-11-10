# Create Views: Event pages

Source: `lily/Features/Create/Views/Event/`

## Overview

The event flow's three step pages, custom glass layouts over the aurora (never `Form`s — the substrate the owner
picked from the 2026-11-10 side-by-side prototype): fields per the plan's step table, composed from the slice-1
shared components, section contents in `GlassCard` containers and text fields in the `lilyField()` /
`lilyMultilineField()` glass capsules (the sign-in look). Every page renders inside `WizardStepScaffold` and binds
to the view model through `EventDraftEditing`; every create field identifier is byte-identical to the form's, so the
UI tests only change navigation.

## Interface

- `EventBasicsPage<Model>` (`lily/Features/Create/Views/Event/EventBasicsPage.swift:EventBasicsPage`): the title
  capsule (`create-title`), the shared `EventTypeChips` under a `CaptionedControl`, the start `DatePicker` (floored
  at `viewModel.earliestStart`) in a card, and the shared `HostingGroupRow` behind an outer label (a menu picker
  outside a `Form` draws no label of its own, so the row is `labelsHidden()` behind `Copy.group`) with the
  no-eligible-groups explanation under it; `WizardIssueHint` closes the page.
- `EventPlacePage<Model>` (`EventPlacePage.swift:EventPlacePage`): the shared `PlaceNameField` in the glass capsule
  (`create-location-name`) owning the debounce and stale-drop rules, its `PlaceSuggestionRows` in one `GlassCard`
  directly under the field (a pick applies the suggestion and clears the rows), then the pick-on-map
  `GlassNavigationRow` (`create-pick-on-map`), its value `spotSet`/`spotNotSet` (human copy, never raw coordinates,
  which stay on the picker screen; design-judge round, 2026-11-10), pushing `LocationPickerView` as the path
  element `CreationStep.eventMap` — the wizard's stack is bound to the typed `[CreationStep]` path, which disables
  a link carrying any other value (the slice-2 review's fix: a `WizardMapDestination` value never pushed), and the
  shell's `navigationDestination` renders the picker; the hint line is the step's first live
  issue, or `whereHint` while nothing is wrong. A map spot goes through `EventDraft.pickSpot` (the user's choice).
- `EventPlayersPage<Model>` (`EventPlayersPage.swift:EventPlayersPage`): the shared `EventPlayersFields` (segmented
  limit `create-player-limit`, stepper `create-capacity`) in a card with the per-limit hint under it, the
  description (`lilyMultilineField`) and looking-for (`lilyField`) capsules, and one card with the level behind an
  outer label (`SkillLevelPicker`, `lilyMenuPicker`, `labelsHidden`) and the shared `PriceAmountField`
  (`create-price`, `create-price-currency`); `WizardIssueHint` closes the page. The scaffold's bottom bar carries
  the submit button here (`create-submit`).

## Invariants

- The issue partition renders where it gates: each page shows only `wizard.firstBlockingIssue(on:)` for its own
  step, through the shared `ValidationHint` copy (`AppBranding.Events.Create.message(for:)`); per-page gating
  refreshes on every render, the final gate stays authoritative in the scaffold.
- Focus and keyboard: the basics and players pages pass their focused field as the scaffold's `scrollTarget` and
  mark the fields with `.id`, so the focused capsule scrolls into view; identifiers are stamped on the fields
  themselves, before the capsule modifiers, so the XCUI queries keep finding the text fields. Every page clears its
  focus when the wizard's path changes (`.onChange(of: wizard.path)` — on disappear the view is already leaving the
  hierarchy and the focus write is ignored): a field left focused keeps the keyboard through a push, and on the
  pop-back the scaffold's bottom bar never picks up that keyboard's inset, leaving Next covered (the slice-2
  review's back walk, 2026-11-10; the place page owns a `FocusState` handed to the shared `PlaceNameField` for
  exactly this).
- No new copy and no literals: every string reads through `AppBranding.Events.Create`, `AppBranding.Events` or
  `AppBranding.Create`.

## Side Effects

- None beyond the bindings into the view model's draft; the geocoder is only reached through the view model's
  `placeSuggestions(for:)` seam (`PlaceNameField`'s debounced task).

## Verification

- Run: `./scripts/ci.sh build` (zero `/lily/` warnings); the model and partition behind the pages:
  `./scripts/ci.sh unit` (`lilyTests/Create/`). The rendered pass (compact and regular, keyboard up, accessibility
  sizes) runs with the Explore wiring per the plan's verification section; the smoke walk
  (`LilySmokeTests.testCreatingAGameShowsItOnHome`) taps `create-pick-on-map` and asserts the picker's bar on a
  simulator.
