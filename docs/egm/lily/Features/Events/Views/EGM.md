# Events Views

Source: `lily/Features/Events/Views/`

## Overview

The SwiftUI screens and components of the Events feature: the Explore screen (`EventListView` with its `+Content`
extension), the event detail, the shared create/edit form and its sheets, the filter button and sheet, the events
map and the location picker, and the cards and rows other features reuse (`EventCard`, `EventCardList`,
`EventPreviewCard`, `EventMapCardList`,
`EventFactsCard`, `EventLocationMap`, `ParticipantRow`, `PlaceFields`, `PlacePickerRow`, `PriceAmountField`,
`SkillLevelPicker`). Views
draw what the [ViewModels](../ViewModels/EGM.md) decide and call back into them; copy comes from `AppBranding`,
sizes from `DesignTokens`, identifiers from `AccessibilityIdentifiers`, decisions from the
[Models](../Models/EGM.md) enums.

## Interface

- `EventListView<Header: View>` (`lily/Features/Events/Views/EventListView.swift`,
  `EventListView+Content.swift`): `init(listTitle: String?, viewModel: EventListViewModel,
  dependencies: AppDependencies, refreshHeader: @escaping () async -> Void, @ViewBuilder header:)`. State:
  `presentation: EventsPresentation`, `presentedSheet: ExploreSheet?`, `headerHeight`. Members: `showsMapAlone`,
  `sheetContent(for:)`, `consumePendingCreate()`, `presentForUser(_:)`,
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
- `EventDraftForm+Place.swift` (2026-11-06): the Where section, split out for the form's file limit; the stored state
  (`suggestions`, `focusedField`) stays in `EventDraftForm.swift`. `pickedCoordinate` is the map row's binding, its
  setter `viewModel.draft.pickSpot($0)` (a non-nil spot becomes the user's: `spotPickedOnMap`, `suggestedName = nil`);
  `suggestionRows` are the geocoder's places for the typed name (titles in `Color.primary`, the glyph on the button's
  accent tint; the rows hold semantic styles only, since a generated asset colour stored in them crashed the list
  diff, see `docs/notes/events.md` 2026-11-06; identifiers `AccessibilityIdentifiers.createPlaceSuggestion(index)`;
  the `ForEach` keys by `PlaceSuggestion.id`, which includes the coordinate), a row's action
  `viewModel.draft.apply(suggestion)` (name, spot and `suggestedName` at once) then clearing the rows and the focus.
  The form's debounced `.task(id: locationName)` (`AppConfig.Events.placeSuggestionDebounce`, 300 ms) asks only while
  `focusedField == .locationName` and `draft.placeSuggestionQuery` is non-nil, through
  `viewModel.placeSuggestions(for:)`; after the await it drops the answer unless the task is live, the field is still
  focused and `draft.placeSuggestionQuery` still equals the query asked (`MKLocalSearch` ignores cancellation, so a
  late answer would otherwise put rows back under a left field or right after a pick).
- `EventFilterButton` (`lily/Features/Events/Views/EventFilterButton.swift`): `viewModel: EventListViewModel`; a
  toolbar button presenting `EventFilterSheet` (`EventFilterSheet.swift`: `viewModel`, `onDone`) as a `lilyFormSheet()`
  (full screen on the iPhone, like the create forms; a dropdown popover before 2026-11-05), the filled/outline glyph and
  the VoiceOver value on the button, one `filterPanelOpened`/`filterPanelClosed` pair per sheet session.
- `EventsMapView` (`lily/Features/Events/Views/EventsMapView.swift`): `init(viewModel: EventListViewModel,
  trailingInset: CGFloat = 0)` (room kept free to the right of the selected cards for a floating button);
  `EventMapPin(type: EventType, isSelected: Bool, count: Int = 1)` (over 1 it wears the count on an accent badge,
  `DesignTokens.Layout.mapPinBadgeInset`); its private `selectedStackCards` draws
  `EventMapCardList(stack:distanceText: viewModel.distanceText(for:))` padded `Spacing.lg` plus `trailingInset`,
  moving in from the bottom with a fade (`lily/Features/Events/Views/EventsMapView.swift:EventsMapView`).
- `EventMapCardList(stack: EventMapStack, distanceText: (SportEvent) -> String?)`
  (`lily/Features/Events/Views/EventMapCardList.swift:EventMapCardList`, split out of `EventsMapView` 2026-11-06): the
  selected stack's cards, one `NavigationLink(value:)` per event: a single event is its card alone on the card's own
  glass, several sit in one glass panel (`Radius.card`) headed by the place and the count, each card drawn
  `EventPreviewCard(surface: .inset)`; private `MapCardButtonStyle(motion:)`
  (moved here with it; dim `Opacity.pressedCard` plus, when `motion.allowsMovement`, shrink `Layout.pressedCardScale`
  exactly while pressed, animated `.easeOut(Duration.fast)` both ways so the release visibly lets go).
- `EventLocationMap(event: SportEvent)` (`lily/Features/Events/Views/EventLocationMap.swift`): the event's spot pinned
  (`EventMapPin`, selected look) at `AppConfig.Location.pickerRegionMeters` scale, `interactionModes: []`, height
  `DesignTokens.Layout.detailMapHeight`, clipped to `Radius.md`, identifier
  `AccessibilityIdentifiers.eventDetailMap`; drawn on the detail after the facts card (2026-11-05, on the user's "I
  should be able to see the map too when opening an event"). Since 2026-11-06 the whole card is a `Button` handing the
  spot to Apple Maps (`MKMapItem(location:address:)`, named after the place, `openInMaps()`), wearing an
  "Open in Maps" chip at its bottom trailing corner, since the map itself does not pan. The `Map` is keyed by
  `.id(event.location.coordinate)`, because `Map(initialPosition:)` is read once per identity and the detail stays on
  screen through an edit (`EventDetailViewModel.accept`): a saved edit that moves the spot rebuilds the camera on the
  new spot. For VoiceOver the card is one `Button` element (no `.accessibilityElement(children: .contain)`, which made
  it a container), labelled `AppBranding.Events.openInMaps` (a Button, so one element with the button trait), the identifier
  `eventDetailMap` on that button.
- `LocationPickerView` (`lily/Features/Events/Views/LocationPickerView.swift`):
  `init(coordinate: Binding<Coordinate?>)`; a map under a fixed pin.
- `PlaceFields<Field: Hashable>` (`lily/Features/Events/Views/PlaceFields.swift`): `init(name:coordinate:
  placeholder: = AppBranding.Events.Create.locationNamePlaceholder, nameIdentifier:pickerIdentifier:
  focus: FocusState<Field?>.Binding, equals:)`, and `where Field == Never` the same without focus.
  `PlacePickerRow(coordinate:)` (`PlacePickerRow.swift`) is the `NavigationLink` to the picker.
- Cards and rows: `EventCard(event:distance:)` (`EventCard.swift`), `EventCardList(events:distance:
  horizontalPadding: = DesignTokens.Layout.screenMargin, singleColumn: = false)` (`EventCardList.swift`),
  `EventPreviewCard(event:detail:surface: = .glass)`
  (`lily/Features/Events/Views/EventPreviewCard.swift:EventPreviewCard`; `Surface` is `.glass`, the card's own
  `Radius.md` glass when it stands alone over the map, or `.inset`, an ink wash at `Opacity.mapPanelCardWash` (0.07) on
  the same radius inside the many-events panel, so glass never sits on glass (2026-11-06); since
  2026-11-06 two rows on that `Radius.md` surface: the sport mark (`AvatarCircle`, `.sport`, `Layout.mapCardMarkSize`), the
  title in `Fonts.itemTitle` and ink, wrapping to `Layout.mapCardTitleLines` (2) rather than cut (its column takes the
  width the mark and the trailing facts leave, and `fixedSize(horizontal: false, vertical: true)` lets it take the
  second line), over the group's name (`Symbols.groups`) or else the place (`Symbols.location`),
  the `detail` (distance) in `.secondary` and the price in ink semibold when not free, trailing; then a footer with the
  abbreviated relative start in an ink capsule (`Opacity.mapCardCapsuleFill`, the `Symbols.time` clock in the accent)
  and the spots beside a `CapacityMeter` `Layout.mapCardMeterWidth` wide when the game has a capacity),
  `EventFactsCard(event:)` (`EventFactsCard.swift`),
  `ParticipantRow(participant:isSelf:)` (`ParticipantRow.swift`), `SkillLevelPicker(selection: Binding<SkillLevel?>)`
  (`SkillLevelPicker.swift`).

## Invariants

- Layout (`EventListView`): `EventListLayout.resolve(mode: layoutMode)`; `.switchable` draws one column with the
  create button floating over it and a segmented list/map `Picker` in the toolbar under
  `.sharedBackgroundVisibility(.hidden)`; `.sideBySide` draws the content column at
  `DesignTokens.Layout.exploreContentFraction` beside a permanent map pane (`accessibilityElement(children:
  .contain)` before `AccessibilityIdentifiers.exploreMapPane`) with no picker.
- `listContent` (`EventListView+Content`) switches on `viewModel.screenState` (the view model's own
  `EventListScreenState`, see [ViewModels](../ViewModels/EGM.md)): `.loading` a
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
  with no action, `.hosting` a caption. The Edit toolbar item (`lilyToolbarTextButton()`) shows only when `canEdit`;
  the roster only when
  `showsParticipants`; `.task` calls `recordViewed()` then `loadParticipants()`.
- Form (`EventDraftForm`): each section footer shows the first matching `viewModel.issue(for:)`: game
  `.titleMissing` / `.titleTooLong` / `.startsAtTooSoon`, where `.locationNameMissing` / `.locationNameTooLong` /
  `.coordinateMissing`, players `.capacityOutOfRange` / `.capacityBelowParticipants`, details
  `.descriptionTooLong` / `.lookingForTooLong` / `.priceUnreadable` / `.priceOutOfRange`. The date picker is
  bounded below by `viewModel.earliestStart`; the capacity `Stepper` appears only when
  `draft.playerLimit.hasCapacity`, over `viewModel.capacityRange`; the group row shows when `showsGroupRow` as the
  read-only `lockedGroup`, read-only "No group" when `explainsNoEligibleGroups`, else a `Picker` over
  `eligibleGroups` styled by `lilyMenuPicker()` (value and chevron in `.secondary`, not the form's accent tint), and
  the details section's `SkillLevelPicker` (a default-styled `Picker` that a `Form` draws as a menu) is styled by
  `lilyMenuPicker()` the same way; the title's submit moves focus to the location name; the price is typed as
  `draft.priceText` through `PriceAmountField`.
- `PriceAmountField` (`lily/Features/Events/Views/PriceAmountField.swift`): `init(text: Binding<String>, placeholder:,
  currencyCode:, label:, identifier:, currencyIdentifier:, focus: FocusState<Bool>.Binding? = nil)`; an `HStack` of a
  trailing `.decimalPad` `TextField` at `DesignTokens.Layout.priceFieldWidth` (focused through `focus` when given,
  with `label` as its accessibility label and `identifier`) and `Price.symbol(for: currencyCode)` in `.secondary`,
  `fixedSize()`, under `currencyIdentifier`. The one decimal-pad price field: the form's price row (no focus binding)
  and the filter sheet's cap (focused by the capsule's tap through `isPriceFocused`).
- `CreateMenuButton`: a `Menu` with game, group and (when `AppConfig.FeatureFlags.tournaments`) tournament while
  `AppConfig.FeatureFlags.groups` is on; a single game button otherwise.
- Filter (`EventFilterSheet`): a `NavigationStack` over a `Form` (sections: type, distance, price; level, dates and
  open spots), title "Filters" inline, Done in `confirmationAction` (closes only; every change applies at once); every
  change goes through `viewModel.updateFilter`, `toggleType` or `clearFilter`;
  Reset (`lilyToolbarTextButton()`, top bar leading) shows only while `filter.isActive`; distance offers
  `AppConfig.Events.filterRadiiMeters` (2, 5, 10, 25 km)
  plus "anywhere" (`nil`), replaced by a note while `userLocation == nil`; "Free only" toggles `maxPrice` between
  `0` and `nil`; typed text clears the cap when empty, sets it when parseable and leaves it when not
  (`applyTypedCap`); dates on proposes `DateWindow.proposal()`, each end edited as whole days through
  `DateWindow.days(from:to:)`. `EventFilterButton` reports the sheet's presentation as `filterPanelOpened()` /
  `filterPanelClosed()`.
- Map (`EventsMapView`): opens on `MapFraming.initialRegion(userLocation:radiusMeters: filter.maxDistanceMeters)` or
  `.userLocation(fallback: .automatic)`; a later position recentres once unless the user panned (`hasCenteredOnUser`,
  `position.positionedByUser`); pins are `viewModel.visibleEvents`; a selection whose stack is gone (the filter hid it, or a reload regrouped the pins) is dropped, through `onChange(of: stacks.map(\.id))`. The pins
  are `EventMapStack.stacks(of: visibleEvents)`: events on one spot (two overlapping pins left the one behind
  unselectable) share a pin labelled with the place and wearing the count, and the selection is the stack's id.
  Selecting one shows a card per member at the bottom leading edge with `trailingInset` kept free on its right, beside
  the floating "+" rather than above it, each a `NavigationLink(value:)` in `MapCardButtonStyle` (`.plain` kept its
  dim after the pop). The selection animates under one implicit `.snappy(Duration.fast)` on `selectedStackID` (nil
  under Reduce Motion, read from `\.motion`); the cards sit at `.zIndex(1)`, so they leave above the map instead of
  sliding out under it; each pin's `onTapGesture` selects at once instead of after MapKit's double-tap wait. The cards
  are drawn by `EventMapCardList` (2026-11-06; the scroll state moved there from `EventsMapView`). Only the map
  `ignoresSafeArea(edges: .bottom)`.
- Card list (`EventMapCardList`): one event is its card alone (`surface: .glass`). A stack of more than one is one
  glass panel (`glassEffect(.regular, in: .rect(cornerRadius: Radius.card))`, padded `Spacing.sm`, at most
  `Layout.mapSelectedCardWidth`) holding a header row, the accent `Symbols.pickedLocation` glyph, the first event's
  `locationName` in ink semibold and `AppBranding.Events.eventsHere(count)` in `.secondary`, combined for
  accessibility, over the cards drawn `surface: .inset` (an ink wash, never glass on the panel's glass). The cards sit
  in a `ScrollView` as tall as its content up to `Layout.mapCardListMaxHeight` (400, about three and a half cards, so
  the cut card says there is more; 352 before 2026-11-06) through `onGeometryChange` into `cardListHeight` (a
  `fixedSize` ignored the cap and overflowed under the "+"), `scrollBounceBehavior(.basedOnSize)`, and scrolled back
  to the top whenever `stack.id` changes (`cardScroll`), so a pin tapped straight after another never opens part-way
  down. That reset (`onChange(of: stack.id)` -> `cardScroll.scrollTo(edge: .top)`) sits on a `ZStack` wrapping both
  the lone-card and the panel branch, so it fires on every selection change, a switch between the two included; on a
  branch's own scroll view it was rebuilt unseen while `cardScroll` kept the old position. Before the first
  measurement the list is `Layout.mapCardListUnmeasuredHeight` (1 pt) tall. The edges come from the scroll geometry, not from which cards are visible: `onScrollGeometryChange` builds
  `MapCardListEdges(offset:contentHeight:containerHeight:)` (see [Models](../Models/EGM.md)), so they hold at
  accessibility type sizes, where one card can be taller than the list. A mask dissolves the top
  `Layout.mapCardListFade` points to clear while `edges.hasMoreAbove` and the bottom ones while `edges.hasMoreBelow`,
  so the cut card fades into the panel (`lily/Features/Events/Views/EventMapCardList.swift:EventMapCardList`). In the panel, while whole
  cards are left below (`MapCardListEdges.cardsBelow(in:visible:)` above zero, so never for a lone card), a "+N more" pill (`Events.moreBelow(MapCardListEdges.cardsBelow(in:visible:))`, `Symbols.moreBelow`,
  `.titleThenIcon`, caption semibold) sits over the bottom as `lilyProminentButton(sizing: .fitted, controlSize:
  .regular)`, white on the accent prominent glass with a full-size target, and scrolls to the end; it enters from
  `Layout.mapMorePillEntryScale` with a fade. The visible cards for its count come from
  `onScrollTargetVisibilityChange` at `Layout.mapCardVisibleShare` (0.01: any part of a card in view counts, so a
  card taller than the list still counts; 0.5 before 2026-11-06). Both fades and the pill animate under one
  `.animation(_, value: edges)`, `.snappy(Duration.fast)`, nil under Reduce Motion. The `mapSelectedCard` identifier
  is on the inner stack, where it stamps the card links (`app.buttons`); set on the scroll view it reached no element.
- Picker (`LocationPickerView`): converts the map frame's centre through `MapProxy.convert` on
  `.onMapCameraChange(frequency: .onEnd)` and writes `coordinate` only when
  `PickerSettlePolicy.isAChoice(spot, current:, isFirstSettle:)`; a chosen spot opens at
  `AppConfig.Location.pickerRegionMeters` (1,500 m), none follows the user.
- Components: `EventFactsCard` shows the price only when `!event.isFree` and the level only when
  `event.skillLevel?.ifKnown` is set; `EventCard` adds a price chip when not free and a `GroupBadge` when hosted in
  a group; `EventPreviewCard` turns each of its two rows into a column at accessibility type sizes (lines up to
  `Layout.accessibilityPreviewLines`, one otherwise) and draws its `detail` (the distance) in `.secondary` like every
  other distance; `SkillLevelPicker` offers
  "Any level" over `SkillLevel.known`, never an unknown level; `EventDraftForm.detailsSection` styles it by
  `lilyMenuPicker()` and `EventFilterSheet.levelRow` the same with its labels hidden, the title drawn on the left like
  the price row's; `ParticipantRow` adds the host chip for
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
