# Events Models

Source: `lily/Features/Events/Models/`

## Overview

The value types of the Events feature, all `nonisolated` and `Sendable`, with no storage or network of their own. The
wire-shaped models (`SportEvent`, `EventLocation`, `EventParticipant`, `Price`, the request bodies
`CreateEventPayload` and `UpdateEventPayload`) keep Laurel's key names and omit optionals; `EventType` and `SkillLevel`
are `WireNamedKind` enums that tolerate unknown values. `EventDraft` is the create/edit form model with its `Issue`
list and `Rules`; `EventFilter`, `PersistedEventFilter` and `DateWindow` are the on-device filter; the rest are small
decision types the view models and views switch on (`EventScope`, `EventListScreenState`, `Participation`,
`PlayerLimit`, `CreateIntentPolicy`, `PickerSettlePolicy`, `MapFraming`, `EventListLayout`, `EventsPresentation`,
`ExploreSheet`, `PlaceDraft`, `EventMapStack`, `MapCardListEdges`). Limits come from `AppConfig.Events`, copy from
`AppBranding.Events`.

## Interface

- `SportEvent` (`lily/Features/Events/Models/SportEvent.swift`): `Identifiable, Hashable, Codable`. Stored: `id`,
  `title`, `type: EventType`, `startsAt: Date`, `location: EventLocation`, `capacity: Int?`,
  `allowsExtraParticipants: Bool`, `participantCount: Int`, `hostName`, `hostUserId: String?`, `isJoined: Bool?`,
  `description?`, `lookingFor?`, `skillLevel: SkillLevel?`, `price: Price?`, `group: EventGroupRef?`. Explicit
  `CodingKeys` and a hand-written `init(from:)`; synthesized `encode(to:)`. Derived: `locationName`, `playerLimit`,
  `spotsLeft`, `isFull`, `isNearlyFull`, `hasPlayersNeeded`, `fillRatio`, `participates`, `isFree`, `isListed`,
  `spotsDescription`, `countDescription`, `priceText`, `availabilityText`, `capacityText`; `isHosted(by:)`,
  `distance(from:) -> Measurement<UnitLength>?`, `updating(with: EventDraft)`, `updatingParticipation(count:isJoined:)`.
- `EventScope` (`SportEvent.swift`): `upcoming`, `joined`, `group(id: String)`; `wireName: String?`
  (`"upcoming"`, `"joined"`, `nil`), `snapshotList: String` (`AppConfig.Lists.upcomingEventsSnapshot` =
  `events-upcoming`, `joinedEventsSnapshot` = `events-joined`, `groupEventsSnapshot(id)` = `events-group-<id>`).
- `EventLocation` (`EventLocation.swift`): `name`, `coordinate: Coordinate`; `distance(from:)`.
  `EventParticipant` (`EventParticipant.swift`): `userId` (the `id`), `displayName`, `joinedAt`, `isHost`.
- `EventType` (`EventType.swift`): `WireNamedKind` with 20 known cases (`football` ... `other`) plus
  `unknown(String)`; `known`, `wireName` (snake_case, e.g. `table_tennis`), `displayName`, `symbolName`, with
  `init(wireName:)` and `isUnknown` from `WireNamedKind`'s defaults. `SkillLevel` (`SkillLevel.swift`): `beginner`,
  `intermediate`, `advanced`,
  `unknown(String)`; `known`, `ifKnown`, `displayName`.
- `Price` (`Price.swift`): `amount: Decimal`, `currencyCode`; `isFree`, `text`, `text(in:)`, `symbol(for:locale:)`,
  `name(for:locale:)`, `inputFormat`, `inputText(_:locale:)`, `parseAmount(_:locale:) -> Decimal?`.
- `EventDraft` (`EventDraft.swift`): `let clientId`, `title`, `type` (default `.football`), `startsAt`,
  `locationName`, `coordinate: Coordinate?`, `spotPickedOnMap` (whether the user chose the spot; a chosen one is never
  overridden by the typed name, a proposed one is), `suggestedName` (the name whose geocoding produced `coordinate`, so
  it is not geocoded twice), `capacity` (default `AppConfig.Events.Creation.defaultCapacity` = 10),
  `playerLimit` (default `.maximum`), `description`, `lookingFor`, `skillLevel?`, `priceText`, `let locale`,
  `let currencyCode`, `group: EventGroupRef?`. Inits `init(startsAt:currencyCode:locale:clientId:)` and
  `init(editing: SportEvent, currencyCode:locale:)`. Nested `Rules` (`minimumLeadTime`, `minimumCapacity`;
  `.creation`, `.editing(participantCount:)`, `capacityRange(for:)`) and `Issue` (`titleMissing`, `titleTooLong`,
  `startsAtTooSoon`, `placeMissing` (neither a name nor a spot; either is enough, the geocoder fills the other on
  submit), `locationNameTooLong`, `capacityOutOfRange`,
  `capacityBelowParticipants`, `descriptionTooLong`, `lookingForTooLong`, `priceUnreadable`, `priceOutOfRange`).
  Derived: `capacityIfLimited`, `allowsExtraParticipants`, `trimmedTitle`, `place: PlaceDraft`,
  `trimmedLocationName`, `trimmedDescription?`, `trimmedLookingFor?`, `isFree`, `hasUnreadablePrice`,
  `price: Decimal? { get set }`, `eventPrice: Price?`; `earliestStart(now:rules:)`, `issues(now:rules:)` (the one
  validity rule; `issues(...).isEmpty` is what the forms read), `makeEvent(hostUserId:hostName:coordinate:)`.
- `EventMapStack` (`EventMapStack.swift`, 2026-11-06): the events standing on one spot of the map, drawn as one pin
  (`id` the coordinate rounded to `AppConfig.Events.mapStackDecimals` (4, about 11 m), `coordinate`, `events` in feed
  order); `title` is the event's title alone or the shared `locationName` once there are several;
  `stacks(of:)` groups keeping the feed's order. Two overlapping pins left the one behind unselectable.
- `MapCardListEdges` (`lily/Features/Events/Models/MapCardListEdges.swift:MapCardListEdges`, 2026-11-06):
  `Equatable, Sendable`; `hasMoreAbove`, `hasMoreBelow`; `none`; `init(hasMoreAbove:hasMoreBelow:)` and
  `init(offset:contentHeight:containerHeight:)` (`offset` how far the content's top has scrolled past the list's top);
  `static func cardsBelow<ID: Equatable>(in ids: [ID], visible: [ID]) -> Int`. What the map's card list fades and its
  "+N more" pill show (see [Views](../Views/EGM.md)).
- `PlaceDraft` (`PlaceDraft.swift`): `name`, `coordinate?`; `Requirement` (`nameAndSpot` for the tournament form,
  `nameOrSpot` for the event form, whose missing half the geocoder fills on submit); `Issue` (`nameMissing`,
  `nameTooLong`, `coordinateMissing`, `placeMissing`); `issues(maxLength:requiring: = .nameAndSpot)`, `location(at:)`. `PlayerLimit` (`PlayerLimit.swift`): `unlimited`,
  `maximum`, `minimum`; `init(capacity:allowsExtraParticipants:)`, `hasCapacity`, `allowsExtraParticipants`.
- `CreateEventPayload` (`CreateEventPayload.swift`): `Encodable`; `clientEventId`, `title`, `type`, `startsAt`,
  `location: Location` (`name`, `coordinate`), `capacity?`, `allowsExtraParticipants`, `description?`,
  `lookingFor?`, `skillLevel?`, `price?`, `groupId?`; `init?(draft:)`. `UpdateEventPayload`
  (`UpdateEventPayload.swift`): the same minus `clientEventId` and `groupId`; `init?(draft:)`.
- `EventFilter` (`EventFilter.swift`): `types: Set<EventType>`, `maxDistanceMeters: Double?` (default
  `AppConfig.Events.defaultFilterRadiusMeters` = 10,000), `maxPrice: Decimal?`, `skillLevel?`,
  `dateWindow: DateWindow?`, `openSpotsOnly`; `everything`, `isActive`, `includes(_:)`,
  `matches(_:from:currencyCode:)`, `toggle(_:)`, `clear()`. `PersistedEventFilter` (`PersistedEventFilter.swift`):
  `Codable` mirror without the date window; `init(_ filter:)`, `filter`. `DateWindow` (`DateWindow.swift`): `start`,
  `end`; `contains(_:)`, `days(from:to:calendar:)`, `proposal(from:calendar:)`.
- Decision types: `EventListScreenState` (`loading`, `failed`, `empty`, `filteredOut`, `list`;
  `resolve(isInitialLoad:loadFailed:hasEvents:isEverythingFilteredOut:awaitsAnswerForPosition:)`), `Participation`
  (`hidden`, `join`, `leave`, `full`, `hosting`; `init(event:userID:)`), `CreateIntentPolicy`
  (`sheet(for:isSignedIn:)`, `decide(intent:presentedSheet:isSignedIn:) -> Decision(consumes:present:)`),
  `PickerSettlePolicy.isAChoice(_:current:isFirstSettle:minimumMoveMeters:)`,
  `MapFraming.initialRegion(userLocation:radiusMeters:) -> MKCoordinateRegion?`, `EventListLayout`
  (`switchable`, `sideBySide`; `resolve(mode: LayoutMode)`), `EventsPresentation` (`list`, `map`; `title`,
  `symbolName`, `wireValue`), `ExploreSheet` (`createGame`, `createGroup`, `createTournament`, `signIn`;
  `init(_ intent: CreateIntent)`).

## Invariants

- Decoding (`SportEvent.init(from:)`): `capacity`, `hostUserId`, `isJoined`, `description`, `lookingFor`,
  `skillLevel`, `price`, `group` may be absent; a missing `allowsExtraParticipants` reads as `false`; the other keys
  are required. Encoding omits `nil` optionals (synthesized), never writes `null`.
- Unknown wire values survive: `WireNamedKind`'s default `init(wireName:)` yields `.unknown(name)` for `EventType` and `SkillLevel`
  and re-encode the same name; `known` excludes `.unknown`; `SkillLevel.ifKnown` is `nil` for it;
  `PersistedEventFilter.filter` drops unknown types and an unknown level.
- Capacity arithmetic (`SportEvent`): `playerLimit = PlayerLimit(capacity:allowsExtraParticipants:)` (`nil` →
  `.unlimited`, else `.minimum` when extras are allowed, else `.maximum`); `spotsLeft = max(capacity -
  participantCount, 0)`; `isFull` only for `.maximum` with no spots; `isNearlyFull` for `.maximum`, not full, and
  `fillRatio >= AppConfig.Events.nearlyFullRatio` (0.75); `hasPlayersNeeded` iff `participantCount >= capacity`.
- `isHosted(by:)` is true only when `hostUserId != nil && hostUserId == userId`; `participates = isJoined ?? false`;
  `isListed = !(group?.isPrivate ?? false)`; `updating(with:)` keeps `id`, `participantCount`, `hostName`,
  `hostUserId`, `isJoined`, `group` and the old coordinate when the draft has none.
- Draft validation (`EventDraft.issues`), in form order: `.titleMissing` / `.titleTooLong`
  (`trimmedTitle.wireLength > AppConfig.Events.Creation.titleMaxLength` = 80); `.startsAtTooSoon` when
  `startsAt < now + rules.minimumLeadTime` (creation 15 min, editing `AppConfig.Events.Editing.startMargin` = 60 s);
  place issues via `PlaceDraft.issues(maxLength: AppConfig.Events.Creation.locationNameMaxLength (120), requiring:
  .nameOrSpot)`, so one half of the place is enough; no capacity issue for
  `.unlimited`, `.capacityOutOfRange` outside `capacityRange` (2...200), `.capacityBelowParticipants` only for
  `.maximum` below `rules.minimumCapacity` (editing: `max(2, participantCount)`); `.descriptionTooLong` (> 1000),
  `.lookingForTooLong` (> 300); `.priceUnreadable` when the text is non-blank but unparseable, `.priceOutOfRange`
  unless `0 <= price < priceLimitExclusive` (10,000,000) with at most two decimals.
- `EventDraft.clientId` is fixed for the draft's lifetime (`let`, default `UUID().uuidString.lowercased()`, the
  event's `id` when editing) and becomes the created `SportEvent.id` in `makeEvent`, which also sets
  `participantCount: 1`, `isJoined: true`. `Rules.capacityRange(for:)` clamps the floor to the upper bound so the
  range never inverts.
- `priceText` is the single source of truth: `price` parses it (`Price.parseAmount`: whole-string match of
  `inputFormat`, 0...2 fraction digits, no grouping, `>= 0`) and its setter rewrites it; `eventPrice` is `nil` when
  free or unparseable. `trimmedDescription` / `trimmedLookingFor` use `nonBlankTrimmed`, so blank text is omitted.
- `CreateEventPayload.init?(draft:)` and `UpdateEventPayload.init?(draft:)` return `nil` without a coordinate;
  `capacity` is `draft.capacityIfLimited` (`nil` lifts the limit), `groupId = draft.group?.id`.
- `EventFilter.matches` requires all of: type in `types` (or none chosen); distance `<= maxDistanceMeters` from the
  origin, skipped when either is `nil`; `price.amount <= maxPrice` in the same `currencyCode` (another currency is
  excluded, free events pass); `skillLevel` equal when both known; `dateWindow.contains(startsAt)`;
  `!openSpotsOnly || !isFull`. `isActive = self != EventFilter()`, so the default radius alone is inactive and
  `everything` (radius `nil`) is active; `clear()` restores the default radius.
- `PersistedEventFilter` sorts `types` by `wireName` so equal selections encode identically and never stores the date
  window. `DateWindow.days` starts at the start of `first`, ends one second before the day after `last` (a last before
  first collapses to one day); `contains` is inclusive; `proposal` spans `AppConfig.Events.defaultFilterDateSpanDays`
  (7) from today.
- `EventListScreenState.resolve`: the no-content cases are `ListState(isInitialLoad:isEmpty: !hasEvents, loadFailed:)`'s
  (`loading`, `failed`, `empty`, each mapped to its own case); `ListState.content` → `list` while any event is visible,
  else `loading` while `awaitsAnswerForPosition`, else `filteredOut`.
- `Participation.init` precedence: `userID == nil` → `hidden`; hosted by the user → `hosting`; `participates` →
  `leave`; `isFull` → `full`; else `join`.
- `CreateIntentPolicy.decide`: no intent → not consumed; an intent while a sheet is up → consumed, nothing presented;
  otherwise consumed with `sheet(for:isSignedIn:)`, which substitutes `.signIn` for a guest.
- `PickerSettlePolicy.isAChoice`: without a current spot, only a settle after the first counts; with one, the move
  must be `>= AppConfig.Location.pickerMinimumMoveMeters` (1 m). `MapFraming.initialRegion` is `nil` without a user
  position, else a square of `2 * radius * DesignTokens.Layout.mapRegionPadding` (1.3) metres.
- `EventListLayout.resolve` is `.sideBySide` only for `LayoutMode.wide`.
- `MapCardListEdges.init(offset:contentHeight:containerHeight:)`: `hasMoreAbove` iff `offset >
  DesignTokens.Layout.mapCardEdgeSlack` (1 pt), `hasMoreBelow` iff `contentHeight - containerHeight - offset >` the
  same slack, so rounding at either end never counts as more. It reads geometry only, never card visibility, so one
  card taller than the list still has more below. `cardsBelow(in:visible:)` is the whole cards after the last id in
  `visible` (the first card when `visible` is empty, before the scroll view reports): none once the last card is in
  view, even while its bottom is cut, and none for a lone card, so the pill never names a card that is not there.

## Side Effects

- Clock and randomness: `DateWindow.proposal(from: .now)` and `Calendar.current` defaults; `EventDraft.init` draws
  `UUID()` for the default `clientId` (`DateWindow.swift`, `EventDraft.swift`).
- Locale: `Price` formatting and parsing and `EventDraft`'s default `locale` read `AppLocale.locale`;
  `EventType.displayName` and `SkillLevel.displayName` go through `localized(_:)` (`Price.swift`, `EventType.swift`,
  `SkillLevel.swift`).
- `MapFraming` builds an `MKCoordinateRegion` (MapKit import, no map interaction); `EventScope.snapshotList` names
  snapshot files but performs no I/O (`MapFraming.swift`, `SportEvent.swift`).

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Events/SportEventTests.swift`,
  `EventDraftTests.swift`, `EventDraftPriceTests.swift`, `EventFilterTests.swift`, `EventTypeTests.swift`,
  `SkillLevelTests.swift`, `EventListScreenStateTests.swift`, `CreateIntentPolicyTests.swift`,
  `PickerSettlePolicyTests.swift`, `MapFramingTests.swift`, `PlaceDraftTests.swift`, `CreateEventPayloadTests.swift`,
  `EventMapStackTests.swift`, `MapCardListEdgesTests.swift`).
- `MapCardListEdgesTests` (`lilyTests/Events/MapCardListEdgesTests.swift`): `aListThatFitsHasNothingBeyondEitherEdge`,
  `aTallListAtItsTopHasMoreBelowOnly`, `midwayThereIsMoreOnBothSides`,
  `atTheEndOnlyAboveRemainsAndRoundingDoesNotCount`, `oneCardTallerThanTheListStillHasMoreBelow`,
  `theCountIsTheCardsAfterTheLastOneInView`, `noCardIsLeftOnceTheLastIsInViewOrThereIsOnlyOne`,
  `beforeAnyReportTheFirstCardCountsAsInView`.
