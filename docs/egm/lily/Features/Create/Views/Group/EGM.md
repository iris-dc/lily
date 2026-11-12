# Create Views: Group pages

Source: `lily/Features/Create/Views/Group/`

## Overview

The group flow's six one-idea pages (slice 3 of the creation-wizard plan, 2026-11-11), in the event pages' language:
custom glass layouts over the aurora, composed from the shared components, rendered inside `WizardStepScaffold` and
bound to the view model through `GroupDraftEditing`; the wizard is read through `CreationWizardControlling`. The
walk is Name / Description / Type / Visibility / Place / Permissions — Visibility deliberately precedes Place (a
recorded supersession): the public-place rule reads on the Visibility caption (and, since 2026-11-11, on the
Place caption where it bites), and the Place page's issues stay
conditional on the choice exactly as `GroupDraft` computes them. Every group form field identifier is byte-identical
to the edit form's.

## Interface

- `GroupNamePage<Model>` (`lily/Features/Create/Views/Group/GroupNamePage.swift:GroupNamePage`): the name capsule
  (`create-group-name`) with the keyboard up on entry and `WizardIssueHint` under it; owns
  `nameTooShort`/`nameTooLong`.
- `GroupDescriptionPage<Model>` (`GroupDescriptionPage.swift:GroupDescriptionPage`): the multiline description
  capsule (`create-group-description`, `lilyMultilineField`); the caption says what it is for and that it is
  optional, and the shared `OptionalMarker` sits under the field (2026-11-11); owns `descriptionTooLong`.
- `GroupTypePage<Model>` (`GroupTypePage.swift:GroupTypePage`): the shared `WizardTypePicker` (the third design
  round, 2026-11-11) — a search field (`create-type-search`) over the compact grid, led by the "Any type" card
  (`create-type-any`, `DesignTokens.Symbols.anyType`; the per-type cards reuse
  `createEventType(_:)`); picking writes `draft.type` (nil for any) and auto-advances; re-entering shows the current
  choice. No issues by design.
- `GroupVisibilityPage<Model>` (`GroupVisibilityPage.swift:GroupVisibilityPage`): one `WizardChoiceCard` per
  `GroupVisibility.allCases` (`create-visibility-public`/`-private`, the visibility's own symbol), auto-advancing,
  with the chosen side's existing explanation under the cards (`Groups.publicFooter`/`privateFooter`); the scaffold
  caption carries the public-place rule (`groupVisibilityCaption`). No issues: one side is always chosen.
- `GroupPlacePage<Model>` (`GroupPlacePage.swift:GroupPlacePage`): the shared `PlaceNameField` in the glass capsule
  (`create-group-location-name`) owning the debounce and stale-drop rules over
  `viewModel.placeSuggestions(for:)`/`draft.placeSuggestionQuery`, its `PlaceSuggestionRows` in one `GlassCard`
  directly under the field (a pick applies the suggestion and clears the rows), then the pick-on-map
  `GlassNavigationRow` (`create-group-pick-on-map`, value `spotSet`/`spotNotSet`) pushing `LocationPickerView` as
  the path element `CreationStep.groupMap`. Owns `locationNameMissing`/`locationNameTooLong`/`coordinateMissing`,
  conditional on the visibility choice; the caption states that rule (`groupPlaceCaption`, 2026-11-11). A private
  draft also wears the shared `OptionalMarker` under the name field, so the marker renders exactly while the place
  is optional.
- `GroupPermissionsPage<Model>` (`GroupPermissionsPage.swift:GroupPermissionsPage`): the final step — the shared
  `GroupPermissionToggles` in one `GlassCard`, the caption naming what the toggles rule and the organisers'
  standing rights (`groupPermissionsCaption`, 2026-11-11); the scaffold's bottom bar carries the create button
  (`create-group-submit`), gated by the whole-draft rule. No issues.

## Invariants

- The issue partition renders where it gates: each page shows only `wizard.blockingMessage(on:)` for its own step;
  the final gate stays authoritative in the scaffold.
- Focus and keyboard: the typing pages pass their focused field as the scaffold's `scrollTarget`, mark the field
  with `.id`, and clear the focus when the wizard's path changes (`.onChange(of: wizard.path)`), so a pop-return
  lands keyboard-down; the name page focuses its field on entry.
- Step captions belong to the scaffold (`WizardStepCopy.swift`); no new copy and no literals — every string reads
  through `AppBranding.Groups.Create`, `AppBranding.Groups`, `AppBranding.Events.Create` or `AppBranding.Create`.
- A map spot goes through `GroupDraft.pickSpot` (the user's choice, `PlacePickingDraft`); a suggestion through
  `draft.apply(_:)` (a proposal).

## Side Effects

- None beyond the bindings into the view model's draft; the geocoder is only reached through the view model's
  `placeSuggestions(for:)` seam (`PlaceNameField`'s debounced task).

## Verification

- Run: `./scripts/ci.sh build` (zero `/lily/` warnings); the model and partition behind the pages:
  `./scripts/ci.sh unit` (`lilyTests/Create/CreationStepsGroupTests.swift`,
  `CreationWizardModelKindsTests.swift`; the suggestion seam in `lilyTests/Groups/CreateGroupViewModelTests.swift`).
  The rendered pass ran with the third design round's capture set; the group walk is pinned on a simulator by
  `LilyDiscoverTests.testCreatingAPublicGroupNeedsAPlaceThatTheDetailShows`.
