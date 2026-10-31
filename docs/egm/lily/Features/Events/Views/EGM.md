# Events Views

Source: `lily/Features/Events/Views/`

## Overview

The SwiftUI screens and components of the Events feature: the Explore screen (`EventListView` with its `+Content`
extension), the event detail, the shared create/edit form and its sheets, the filter button and panel, the events
map and the location picker, and the cards and rows other features reuse (`EventCard`, `EventCardList`,
`EventPreviewCard`, `EventFactsCard`, `ParticipantRow`, `PlaceFields`, `PlacePickerRow`, `SkillLevelPicker`). Views
draw what the [ViewModels](../ViewModels/EGM.md) decide and call back into them; copy comes from `AppBranding`,
sizes from `DesignTokens`, identifiers from `AccessibilityIdentifiers`, decisions from the
[Models](../Models/EGM.md) enums.

## Interface

- `EventListView<Header: View>` (`lily/Features/Events/Views/EventListView.swift`,
  `EventListView+Content.swift`): `init(listTitle: String?, viewModel: EventListViewModel,
  dependencies: AppDependencies, refreshHeader: @escaping () async -> Void, @ViewBuilder header:)`. State:
  `presentation: EventsPresentation`, `presentedSheet: ExploreSheet?`, `headerHeight`. Members: `showsMapAlone`,
  `screenState: EventListScreenState`, `sheetContent(for:)`, `consumePendingCreate()`, `presentForUser(_:)`,
  `presentationPicker`, `content`, `listContent`, `eventList`, `filteredOutState`, `loadFailedState`,
  `emptyState`, `stateSlot`, `refreshableScroll`.
- `EventDetailView` (`lily/Features/Events/Views/EventDetailView.swift`): `init(viewModel: EventDetailViewModel,
  dependencies: AppDependencies)`; hosts `EditEventSheet` in `.sheet(isPresented:)`.
- `EventDraftForm<Model: EventDraftEditing>` (`lily/Features/Events/Views/EventDraftForm.swift`):
  `@Bindable var viewModel: Model`; a `Form` with game, where, players and details sections.
- `EventDraftSheet<Model: EventDraftEditing>` (`lily/Features/Events/Views/EventDraftSheet.swift`): `viewModel`,
  `title`, `submitTitle`, `errorCenter`; wraps Core's `DraftSheet` around `EventDraftForm`. `CreateEventSheet`
  (`CreateEventSheet.swift`: `CreateEventViewModel`, `ErrorCenter`) and `EditEventSheet` (`EditEventSheet.swift`:
  `EditEventViewModel`, `ErrorCenter`) are its two titled uses.
- `CreateMenuButton` (`lily/Features/Events/Views/CreateMenuButton.swift`): `onCreateGame`, `onCreateGroup`,
  `onCreateTournament: () -> Void = {}`; the floating "+".
- `EventFilterButton` (`lily/Features/Events/Views/EventFilterButton.swift`): `viewModel: EventListViewModel`; a
  `FilterDropdownButton` presenting `EventFilterPanel` (`EventFilterPanel.swift`: `viewModel`, `onDone`).
- `EventsMapView` (`lily/Features/Events/Views/EventsMapView.swift`): `init(viewModel: EventListViewModel,
  bottomInset: CGFloat = 0)`; `EventMapPin(type: EventType, isSelected: Bool)`.
- `LocationPickerView` (`lily/Features/Events/Views/LocationPickerView.swift`):
  `init(coordinate: Binding<Coordinate?>)`; a map under a fixed pin.
- `PlaceFields<Field: Hashable>` (`lily/Features/Events/Views/PlaceFields.swift`): `init(name:coordinate:
  placeholder: = AppBranding.Events.Create.locationNamePlaceholder, nameIdentifier:pickerIdentifier:
  focus: FocusState<Field?>.Binding, equals:)`, and `where Field == Never` the same without focus.
  `PlacePickerRow(coordinate:)` (`PlacePickerRow.swift`) is the `NavigationLink` to the picker.
- Cards and rows: `EventCard(event:distance:)` (`EventCard.swift`), `EventCardList(events:distance:
  horizontalPadding: = DesignTokens.Layout.screenMargin, singleColumn: = false)` (`EventCardList.swift`),
  `EventPreviewCard(event:detail:)` (`EventPreviewCard.swift`), `EventFactsCard(event:)` (`EventFactsCard.swift`),
  `ParticipantRow(participant:isSelf:)` (`ParticipantRow.swift`), `SkillLevelPicker(selection: Binding<SkillLevel?>)`
  (`SkillLevelPicker.swift`).

## Invariants

- Layout (`EventListView`): `EventListLayout.resolve(mode: layoutMode)`; `.switchable` draws one column with the
  create button floating over it and a segmented list/map `Picker` in the toolbar under
  `.sharedBackgroundVisibility(.hidden)`; `.sideBySide` draws the content column at
  `DesignTokens.Layout.exploreContentFraction` beside a permanent map pane (`accessibilityElement(children:
  .contain)` before `AccessibilityIdentifiers.exploreMapPane`) with no picker.
- `screenState` (`EventListView+Content`) is `EventListScreenState.resolve(...)` from the view model's
  `isInitialLoad`, `loadFailed`, `events`, `isEverythingFilteredOut` and `awaitsAnswerForPosition`: `.loading` a
  `ProgressView`, `.failed` / `.empty` / `.filteredOut` an `EmptyStateView` (filtered-out offers
  `viewModel.showEverything`), `.list` the title and `EventCardList(events: viewModel.visibleEvents, distance:
  viewModel.distanceText)`. Each state has its own `refreshableScroll` under the header; `showsMapAlone` replaces it
  all with the map.
- Triggers (`EventListView`): `.task(id: dependencies.eventChanges.version)` → `loadIfStaleNearTheUser()`;
  `scenePhase` becoming `.active` → `refreshUserLocation()`; `presentation` change → `presentationChanged(to:)`;
  `navigation.pendingCreate` (with `initial: true`) → `consumePendingCreate()`, which applies
  `CreateIntentPolicy.decide` and clears `pendingCreate` when consumed.
- `presentForUser` routes the "+" choice through `CreateIntentPolicy.sheet(for:isSignedIn:)`: a guest gets `.signIn`,
  logged at info under `.auth`. `CreateEventSheet` is built with `onCreated: viewModel.add`; the detail destination
  with `onChange: viewModel.replace`.
- Detail (`EventDetailView.participationControl`) switches on `viewModel.participation`: `.hidden` nothing, `.join` a
  prominent `BusyButton` → `join()`, `.leave` a glass `BusyButton` → `leave()`, `.full` a prominent `BusyButton`
  with no action, `.hosting` a caption. The Edit toolbar item shows only when `canEdit`; the roster only when
  `showsParticipants`; `.task` calls `recordViewed()` then `loadParticipants()`.
- Form (`EventDraftForm`): each section footer shows the first matching `viewModel.issue(for:)`: game
  `.titleMissing` / `.titleTooLong` / `.startsAtTooSoon`, where `.locationNameMissing` / `.locationNameTooLong` /
  `.coordinateMissing`, players `.capacityOutOfRange` / `.capacityBelowParticipants`, details
  `.descriptionTooLong` / `.lookingForTooLong` / `.priceUnreadable` / `.priceOutOfRange`. The date picker is
  bounded below by `viewModel.earliestStart`; the capacity `Stepper` appears only when
  `draft.playerLimit.hasCapacity`, over `viewModel.capacityRange`; the group row shows when `showsGroupRow` as the
  read-only `lockedGroup`, read-only "No group" when `explainsNoEligibleGroups`, else a `Picker` over
  `eligibleGroups`; the title's submit moves focus to the location name; the price is typed as `draft.priceText` on
  a `.decimalPad`.
- `CreateMenuButton`: a `Menu` with game, group and (when `AppConfig.FeatureFlags.tournaments`) tournament while
  `AppConfig.FeatureFlags.groups` is on; a single game button otherwise.
- Filter (`EventFilterPanel`): every change goes through `viewModel.updateFilter`, `toggleType` or `clearFilter`;
  Reset shows only while `filter.isActive`; distance offers `AppConfig.Events.filterRadiiMeters` (2, 5, 10, 25 km)
  plus "anywhere" (`nil`), replaced by a note while `userLocation == nil`; "Free only" toggles `maxPrice` between
  `0` and `nil`; typed text clears the cap when empty, sets it when parseable and leaves it when not
  (`applyTypedCap`); dates on proposes `DateWindow.proposal()`, each end edited as whole days through
  `DateWindow.days(from:to:)`. `EventFilterButton` reports the panel's presentation as `filterPanelOpened()` /
  `filterPanelClosed()`.
- Map (`EventsMapView`): opens on `MapFraming.initialRegion(userLocation:radiusMeters: filter.maxDistanceMeters)`
  or `.userLocation(fallback: .automatic)`; a later position recentres once unless the user panned
  (`hasCenteredOnUser`, `position.positionedByUser`); pins are `viewModel.visibleEvents`; a selection the filter
  hides is dropped; the selected card is a `NavigationLink(value:)` above `bottomInset`; only the map
  `ignoresSafeArea(edges: .bottom)`.
- Picker (`LocationPickerView`): converts the map frame's centre through `MapProxy.convert` on
  `.onMapCameraChange(frequency: .onEnd)` and writes `coordinate` only when
  `PickerSettlePolicy.isAChoice(spot, current:, isFirstSettle:)`; a chosen spot opens at
  `AppConfig.Location.pickerRegionMeters` (1,500 m), none follows the user.
- Components: `EventFactsCard` shows the price only when `!event.isFree` and the level only when
  `event.skillLevel?.ifKnown` is set; `EventCard` adds a price chip when not free and a `GroupBadge` when hosted in
  a group; `EventPreviewCard` turns from a row into a column at accessibility type sizes; `SkillLevelPicker` offers
  "Any level" over `SkillLevel.known`, never an unknown level; `ParticipantRow` adds the host chip for
  `participant.isHost`.

## Side Effects

- View-model calls: `loadIfStaleNearTheUser`, `refreshUserLocation`, `load` (pull-to-refresh, after
  `refreshHeader()`), `presentationChanged`, `showEverything`, `updateFilter` / `toggleType` / `clearFilter`,
  `filterPanelOpened` / `filterPanelClosed`, `distanceText`, `recordViewed`, `loadParticipants`, `join`, `leave`,
  `accept`; the form writes `viewModel.draft` through bindings.
- Navigation: `navigationDestination(for: SportEvent.self)` pushes `EventDetailView`;
  `.groupDestinations(dependencies:)`; `PlacePickerRow` pushes `LocationPickerView`;
  `dependencies.navigation.open(group:)` / `open(tournament:)` after a create from Explore;
  `navigation.pendingCreate = nil` when consumed; `LocationPickerView` calls `dismiss()` on Done.
- Sheets: `CreateEventSheet`, `CreateGroupSheet`, `CreateTournamentSheet`, `SignInSheet` (through `ExploreSheet`) and
  `EditEventSheet`; `EventDraftSheet` hands `errorCenter` to Core's `DraftSheet`.
- `dependencies.tournamentChanges.recordChange()` after a tournament is created from Explore.
- Logging: `.ui` debug when a create shortcut is dropped because a sheet is up; `.auth` info when a guest is sent
  to sign in.
- MapKit: `Map` with `UserAnnotation()` and `MapUserLocationButton()`; `MapReader` / `MapProxy.convert` in the
  picker.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Events/EventListScreenStateTests.swift`,
  `MapFramingTests.swift`, `PickerSettlePolicyTests.swift`); the screens are exercised by `./scripts/ci.sh ui`
  (`lilyUITests`).
