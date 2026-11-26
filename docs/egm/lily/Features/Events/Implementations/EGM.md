# Events Implementations

Source: `lily/Features/Events/Implementations/`

## Overview

The concrete types behind the two Events protocols in [Interfaces](../Interfaces/EGM.md). `RemoteEventRepository`
maps each `EventRepository` call to one Laurel request through `APIClient.send(_:failingWith:)`;
`MockEventRepository` serves `MockEventFixtures` from memory with the backend's refusals and mirrors joins, leaves,
creates and edits into the group mock's event rooms (2026-11-15), for previews, UI tests and
`-mock-events` runs without a backend. `UserDefaultsEventFilterStore` keeps Explore's filter across launches as
`PersistedEventFilter` JSON; `NoOpEventFilterStore` stores nothing for lists whose filter is not worth keeping. The
classes carry no `nonisolated` marker and so run on the main actor by the target's default; `MockEventFixtures` is a
`nonisolated enum`.

## Interface

- `RemoteEventRepository` (`lily/Features/Events/Implementations/RemoteEventRepository.swift`): `final class`,
  `init(client: any APIClient)`; `EventRepository` conformance: `events(in:near:)`, `event(id:)`,
  `participants(eventId:)`, `join(eventId:)`, `leave(eventId:)`, `create(_:)`, `update(id:_:)`. Private
  `static listRequest(for: EventScope, near: Coordinate?) -> APIRequest<[SportEvent]>` and `scopeItems(for:)`.
- `MockEventRepository` (`lily/Features/Events/Implementations/MockEventRepository.swift`): `final class`,
  `init(now: Date = .now, identity: any IdentityProvider, logger: any Logging, failsFirstLoad: Bool = false,
  deletedHost: Bool = false)` (the fixture set is always `MockEventFixtures.feed(now:)`, so the repository and the
  group fixtures' rooms can never disagree on which games exist; `now` stays stored as the divide between upcoming
  and history, 2026-11-25); the same seven methods over an
  in-memory `[SportEvent]`; `rooms: MockGroupRepository?` (the event rooms the writes mirror into, set by the
  composition root; wiring registers a room for any held event the group fixtures do not ship — the appended
  deleted-host game) and `stored(_ eventId:) throws -> SportEvent` (the invite mock's read), 2026-11-15.
- `MockEventFixtures` (`lily/Features/Events/Implementations/MockEventFixtures.swift`,
  `MockEventFixtures+Participants.swift`, and `MockEventFixtures+Rooms.swift`, 2026-11-15: `eventIDPrefix` =
  `mock-event-`, `sunsetEventID` = `mock-event-0`, `isInitiallyJoined(index:)` (every fourth), `feed(now:)` (the one
  fixture feed, `mockFeedSize` events, that the repository serves and `rooms(now:)` / `roster(for:now:)` build from),
  `rooms(now:)`,
  `room(for:membership:lastMessageId:lastMessageAt:createdAt:)` — kind `.event`, the event's `channelEpoch`, private
  visibility iff the group fixture's — and `roster(for:now:)`, the host the owner): `static func make(now: Date, count: Int) -> [SportEvent]`;
  `static func deletedHostEvent(now:) -> SportEvent` (2026-11-07, `-mock-deleted-user`: id `mock-event-deleted-host`,
  started three days ago, the placeholder host name with `deleted: true` — the stamp pass's shape, past because the
  job cancels upcoming hosted games — joined, appended by `MockEventRepository.init` under `deletedHost`, its room
  registered with a member row when `rooms` is wired);
  `static func pastGames(now:) -> [SportEvent]` (2026-11-25: three joined, started games — ids
  `mock-event-past-0/1/2`, 2, 9 and 30 days back, so the latest leads — served for `.past` alone and outside the
  feed, yet resolving by id with rooms registered on wiring, so an Activity row opens the detail, 2026-11-26);
  `static let participantNames` (11 names), `hostJoinLead: TimeInterval` (7 days), `joinSpacing` (1 hour); the
  fixtures start `firstStartHours` (3) plus `hoursBetweenEvents` (7) per index after `now`, in `TimeInterval.hour`;
  `static func participantNames(for: SportEvent, count: Int) -> [String]`.
- `UserDefaultsEventFilterStore` (`lily/Features/Events/Implementations/UserDefaultsEventFilterStore.swift`):
  `final class`, `init(defaults: UserDefaults = .standard, logger: any Logging)`; `load() -> EventFilter?`,
  `save(_:)`, `clear()`.
- `NoOpEventFilterStore` (`lily/Features/Events/Implementations/NoOpEventFilterStore.swift`): `final class`;
  `load()` answers `nil`, `save` and `clear` do nothing.
- `RemoteEventInviteRepository: InviteRepository`
  (`lily/Features/Events/Implementations/RemoteEventInviteRepository.swift`, 2026-11-15): `init(client:)`; the two
  `InviteRepository` calls over `GET AppConfig.API.Paths.eventInvitees(id:)` and `POST eventInvites(id:)`; a private
  send remaps the shared wire codes to event copy — `.alreadyJoined` → `.inviteeAlreadyJoined`,
  `.insufficientRole` → `.cannotInviteToEvent`, `.tournamentInviteLimit` (the shared `INVITE_LIMIT`) →
  `.eventInviteLimit` — with fallback `.inviteUnavailable`.
- `MockEventInviteRepository: InviteRepository`
  (`lily/Features/Events/Implementations/MockEventInviteRepository.swift`, 2026-11-15):
  `init(groups:events:identity:logger:now:)`; refuses a guest (`.sessionExpired`) and a caller neither hosting nor
  joined (`.cannotInviteToEvent`); the send refuses, in the backend's order (2026-11-23), a missing invitee
  (`.userNotFound`), one already in (`.inviteeAlreadyJoined`), then a started event (`.eventStarted`), while the
  candidates still answer for a started event; candidates from the shared
  `MockInviteCandidatePool` minus the event's participants and the caller; sends through the shared
  `MockInviteLedger` into `InviteTarget.event(id:)`.

## Invariants

- Request shape (`RemoteEventRepository.listRequest`): `.group(id)` → `GET` `AppConfig.API.Paths.groupEvents(id:)`
  with no query; `.upcoming` → `GET` `AppConfig.API.Paths.events` with `scope=upcoming` plus the position's `lat`
  and `lon` (`Coordinate.queryItems`, `lily/Core/Networking/Models/Coordinate+QueryItems.swift`: the `coarse`
  position printed with `AppConfig.Events.positionPrecision` decimals) when one is given; `.joined` →
  `scope=joined` and never a position.
- Fallback errors (`RemoteEventRepository`): reads fail with `.eventsUnavailable`, `join` and `leave` with
  `.participationFailed`, `create` with `.eventCreationFailed`, `update` with `.eventUpdateFailed`; `create` and
  `update` throw their fallback before any request when `CreateEventPayload(draft:)` or `UpdateEventPayload(draft:)`
  is `nil` (no coordinate).
- Room mirroring (2026-11-15): the mock's `join` runs `rooms?.admitToEventRoom(for:)` on the joined answer; `leave`
  bumps the event's `channelEpoch` by one (`updatingParticipation(..., channelEpoch:)`, the backend's rule) and runs
  `leaveEventRoom(for:)`; `create` runs `registerEventRoom(for:)`; `update` runs `syncEventRoom(for:)`; every fixture
  event ships a room (`MockGroupFixtures.make` appends `MockEventFixtures.rooms(now:)`), and wiring `rooms` registers
  one for any held event the fixtures do not ship, so every event has a room, as on the backend.
- `RemoteEventRepository.participants` decodes `Page<EventParticipant>` and returns `items`: the backend sends
  `{items: [...]}` without a cursor.
- Fixtures (`MockEventFixtures.make`): nine `Template`s cycled by `index % templates.count`; id
  `mock-event-<index>`; start `now + 3 h + index * 7 h`; coordinates `Coordinate.aroundMockCenter(lat:lon:)`
  (`lily/Core/Location/Models/Coordinate+MockOffset.swift`: offsets as fractions of
  `AppConfig.Location.fixtureSpreadDegrees` around `AppConfig.Location.mockCenter`); prices in
  `AppConfig.Currency.defaultCode`; two templates carry a group (`MockGroupFixtures.kickersID`, `padelID`); two
  carry `durationHours` (the Hills ride 3 h, Sunrise yoga 1 h), so `endsAt` reaches the mock world in both shapes
  (2026-11-11). In
  `MockEventRepository.init` every fourth fixture starts joined (`joinedStride = 4`).
- `MockEventRepository.events(in:near:)` ignores the position: `.upcoming` → `filter(\.isListed)` (a private group's
  game is never on Explore), `.joined` → `filter(\.participates)`, `.past` → the held events plus
  `MockEventFixtures.pastGames(now:)`, filtered to joined games that have started and sorted latest first
  (2026-11-25), `.group(id)` → `group?.id == id`. With
  `failsFirstLoad`, the first list call throws `AppError.network` once (`failsNextLoad` then clears); reads by id,
  joins and creates never fail that way.
- Refusals mirror Laurel (`MockEventRepository`): `find` throws `.eventNotFound`; `join` throws `.alreadyJoined`
  before `.eventFull`; `leave` throws `.hostCannotLeave` before `.notAParticipant`; `update` throws `.notHost`,
  then `.capacityTooLow` when `playerLimit == .maximum && capacity < participantCount`; `create` throws
  `.eventCreationFailed` without a coordinate.
- `MockEventRepository.create` is idempotent on `draft.clientId`: an event already stored under that id is returned
  unchanged ("replayed") when the draft equals the one stored for it (`drafts`), and refused with `.createIdReused`
  when it differs, as Laurel compares the request with what it stored; otherwise `draft.makeEvent(hostUserId:
  identity.currentUserID, hostName: AppBranding.Events.Create.mockHostName, coordinate:)` is appended. `update`
  stores the new draft, so a replay must match the latest details.
- `MockEventRepository.participants`: the host first (`joinedAt = startsAt - hostJoinLead`), then
  `participantCount - 1` deterministic names an hour apart, or `participantCount - 2` when the caller's own row
  follows, so the roster is always `participantCount` long (`participantNames(for:count:)` starts at an offset from
  the id's scalar sum, excludes the host), then the caller as `mockHostName` when they joined and are not the host;
  the host id is `hostUserId` or `MockGroupFixtures.memberID(for: hostName)`, other ids resolve through
  `MockGroupFixtures.memberID(for:)`.
- Filter store (`UserDefaultsEventFilterStore`): key `AppConfig.Storage.Keys.eventFilter` = `lily.events.filter`;
  a stored value that fails to decode reads as `nil` so the defaults apply; an encoding failure leaves the stored
  value untouched; the criteria themselves are never logged.

## Side Effects

- Network (`RemoteEventRepository`, paths from `AppConfig.API.Paths` in `lily/Config/AppConfig.swift` and
  `lily/Config/AppConfig+Groups.swift`): `GET /api/events?scope=…[&lat=…&lon=…]`, `GET /api/groups/{id}/events`,
  `GET /api/events/{id}`, `GET`, `POST` and `DELETE /api/events/{id}/participants`, `POST /api/events` with a
  `CreateEventPayload` body, `PUT /api/events/{id}` with an `UpdateEventPayload` body.
- UserDefaults (`UserDefaultsEventFilterStore`): `data(forKey:)`, `set(_:forKey:)` and `removeObject(forKey:)` under
  `lily.events.filter`.
- Logging: the filter store under `.cache` (debug on a miss and on save, info on restore with `isActive` and on
  clear, warning on a decode or encode failure); `MockEventRepository` under `.events` (debug for each served scope,
  event and roster; info on create and update with `spotsDescription` and on replay with the id alone; warning for
  the requested first-load failure).
- In-memory state (`MockEventRepository`): `events` is mutated by `join`, `leave`, `update` (`store`) and `create`
  (`append`); `drafts` keeps each client id's draft, so a repeated create with other details is `.createIdReused`;
  `failsNextLoad` flips to `false` after the one failure.
- Clock: `MockEventRepository.init` defaults `now` to `.now`; `MockEventFixtures.make` derives every start from the
  `now` it is given.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Events/RemoteEventRepositoryTests.swift`,
  `MockEventRepositoryTests.swift`, `MockEventRepositoryCreateTests.swift`,
  `MockEventRepositoryParticipationTests.swift`, `MockEventRepositoryUpdateTests.swift`,
  `MockEventRepositoryFailureTests.swift`, `EventFilterStoreTests.swift`).
