# Create Views: Event pages

Source: `lily/Features/Create/Views/Event/`

## Overview

The event flow's seven one-idea pages (the owner's second design round, 2026-11-10, superseding slice 2's three-step
grouping): custom glass layouts over the aurora (never `Form`s — the substrate the owner picked from the 2026-11-10
side-by-side prototype), composed from the slice-1 shared components, section contents in `GlassCard` containers and
text fields in the `lilyField()` / `lilyMultilineField()` glass capsules. Every page renders inside
`WizardStepScaffold` (progress mark, optional caption, entrance motion, bottom bar), binds to the view model
through `EventDraftEditing` and reads the wizard through `CreationWizardControlling` (slice 3, 2026-11-11 — a page
is generic over its own kind's view model alone); every create field identifier is byte-identical to the form's, so
the UI tests only change navigation. The walk is Name / Type / When / Hosting group / Place / Players / Details, the hosting-group
page conditional on the opening (`CreationSteps.eventSteps(opening:)`).

## Interface

- `EventNamePage<Model>` (`lily/Features/Create/Views/Event/EventNamePage.swift:EventNamePage`): the title capsule
  (`create-title`) with the keyboard up on entry (`.onAppear` focuses the field; the scaffold's `scrollTarget`
  keeps it visible) and `WizardIssueHint` under it; the partition gives it `titleMissing`/`titleTooLong`.
- `EventTypePage<Model>` (`EventTypePage.swift:EventTypePage`): one `WizardChoiceCard` per `EventType.known`
  (`create-type-<wireName>`, `AccessibilityIdentifiers.createEventType(_:)`), the accent check on the draft's
  current type; picking writes `draft.type` and auto-advances through `wizard.advance(from:)` — the push animation
  is the stack's own — and re-entering shows the current choice, whose card advances again. No issues by design.
- `EventWhenPage<Model>` (`EventWhenPage.swift:EventWhenPage`): the start `DatePicker` floored at
  `viewModel.earliestStart` in a `GlassCard`; owns `startsAtTooSoon`.
- `EventGroupPage<Model>` (`EventGroupPage.swift:EventGroupPage`): on the walk exactly when the opening offers the
  choice (groups flag on, no locked seed, a group to host in at opening — `Opening.hasEligibleGroups`); the shared
  `HostingGroupRow` behind an outer label (`create-group`, `labelsHidden()`), a `ProgressView` placeholder in the
  card until `viewModel.hasLoadedGroups`, and — should the groups change between the opening and the prepare read —
  the read-only "No group" row with the no-eligible-groups explanation under the card, both keyed on the same
  loaded-and-empty read; the scaffold's caption says what hosting in a group means and that No group keeps the
  event open. No issues: an optional choice has nothing to refuse.
- `EventPlacePage<Model>` (`EventPlacePage.swift:EventPlacePage`): the shared `PlaceNameField` in the glass capsule
  (`create-location-name`) owning the debounce and stale-drop rules, its `PlaceSuggestionRows` in one `GlassCard`
  directly under the field (a pick applies the suggestion and clears the rows), then the pick-on-map
  `GlassNavigationRow` (`create-pick-on-map`), its value `spotSet`/`spotNotSet` (human copy, never raw coordinates;
  design-judge round, 2026-11-10), pushing `LocationPickerView` as the path element `CreationStep.eventMap` — the
  wizard's stack is bound to the typed `[CreationStep]` path, which disables a link carrying any other value, and
  the shell's `navigationDestination` renders the picker. The either-half-is-enough line is the scaffold caption
  (`eventPlaceCaption`, aliasing `whereHint`); the hint slot carries the step's issues alone
  (`placeMissing`/`locationNameTooLong`). A map spot goes through `EventDraft.pickSpot` (the user's choice).
- `EventPlayersPage<Model>` (`EventPlayersPage.swift:EventPlayersPage`): the shared `EventPlayersFields` (segmented
  limit `create-player-limit`, stepper `create-capacity`) in a card with the per-limit hint under it, and the level
  behind an outer label (`SkillLevelPicker`, `lilyMenuPicker`, `labelsHidden`); owns
  `capacityOutOfRange`/`capacityBelowParticipants`.
- `EventDetailsPage<Model>` (`EventDetailsPage.swift:EventDetailsPage`): the final step, all of it optional (the
  scaffold caption says so) — one card with the shared `PriceAmountField` (`create-price`, `create-price-currency`),
  the description (`lilyMultilineField`) and looking-for (`lilyField`) capsules; `WizardIssueHint` closes the page
  and the scaffold's bottom bar carries the submit button here (`create-submit`). Owns the remaining issues
  (`descriptionTooLong`, `lookingForTooLong`, `priceUnreadable`, `priceOutOfRange`).

## Invariants

- The issue partition renders where it gates: each page shows only `wizard.blockingMessage(on:)` for its own
  step (the model maps the copy through `AppBranding.Events.Create.message(for:)`), in the shared `ValidationHint`
  look; per-page gating refreshes on every render, the final gate stays authoritative in the scaffold.
- Focus and keyboard: the name and details pages pass their focused field as the scaffold's `scrollTarget` and mark
  the fields with `.id`; identifiers are stamped on the fields themselves, before the capsule modifiers, so the
  XCUI queries keep finding the text fields. Every page with a field clears its focus when the wizard's path changes
  (`.onChange(of: wizard.path)` — on disappear the view is already leaving the hierarchy and the focus write is
  ignored): a field left focused keeps the keyboard through a push, and on the pop-back the scaffold's bottom bar
  never picks up that keyboard's inset, leaving Next covered (the slice-2 review's back walk, 2026-11-10). The name
  page focuses its field on entry — the owner's keyboard-up-on-entry rule — which also re-presents the keyboard on
  a pop-return.
- Step captions belong to the scaffold (`AppBranding.Create.event*Caption`), never to the pages, so the one-line
  rule and the secondary-ink style are pinned in one place.
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
