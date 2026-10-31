# Realtime

Source: `lily/Core/Realtime/`

## Overview

The one realtime connection of a signed-in, foregrounded app. `RealtimeSessionController` subscribes to the caller's own
channel (`users/<sub>`) plus the open chat room and the most recently active groups of Mine, applies what arrives to the
shared chat room cache and the stores, and hands every room envelope to whoever listens through `envelopes(for:)`. It
opens when the app is active with a user and an endpoint, closes on background and sign-out, renews itself with a fresh
token before the token expires, follows channel epochs (a room is `rooms/<groupId>/<epoch>`, bumped on every leave,
removal and ban), and recovers over REST whatever the socket missed. The socket carries only what the backend
committed; every write is REST. The class is split into the main file (state, desired set, shell inputs),
`+Connection.swift` (open, renew, back off, close, resume protocol) and `+Routing.swift` (subscriptions and what
arrives on them).

## Interface

- Children: [Interfaces](./Interfaces/EGM.md) (`RealtimeTransport`, `RealtimeEndpointProvider`),
  [Models](./Models/EGM.md) (`RealtimeEnvelope`, `RealtimeChannel`, `RealtimeConnectionState`,
  `RealtimeTransportError`, `Backoff`, `RenewalDelay`), [Implementations](./Implementations/EGM.md) (mock and
  no-op transports, endpoint providers).
- `@Observable final class RealtimeSessionController: SessionObserver` (main-actor). Observable state read by
  screens: `var state: RealtimeConnectionState` (starts `.disconnected`), `var subscribedRooms: [String: Int]` (the
  epoch each room is subscribed at), `var openRoom: RoomSubscription?`
  [`lily/Core/Realtime/RealtimeSessionController.swift:RealtimeSessionController`].
- Internal state shared with the extensions: `isActive`, `user: AuthUser?`, `wantedRooms`, `knownEpochs: [String: Int]`,
  `connectionGeneration`, the tasks `connectionTask: Task<Bool, Never>?`, `renewalTask`, `reconnectTask`,
  `subscriptions: [RealtimeChannel: Subscription]`, `pendingResubscribes: [String: Task<Void, Never>]`,
  `consumers: [UUID: Consumer]`, and `lastExpiry`, `backoff: Backoff`, `reconnectsWithoutToken`,
  `reportedExpiredSession`; nested `Consumer { groupID, continuation }` and `Subscription { id: UUID, task }`
  [`RealtimeSessionController.swift:RealtimeSessionController`].
- Dependencies (init): `transport: any RealtimeTransport`, `endpointProvider: any RealtimeEndpointProvider`,
  `tokenProvider: (any AuthTokenProvider)?` (`nil` under mock auth), `identity: any IdentityProvider`,
  `store: MyGroupsStore`, `cache: any ChatHistoryCache`, `catchUp: ChatCatchUp`, `unread: UnreadCenter`,
  `inbox: InboxStore`, `groupChanges: ChangeTracker`, `tournamentChanges: ChangeTracker`,
  `groupRepository: any GroupRepository`, `errorCenter: ErrorCenter`, `logger: any Logging`, and the injectable
  `now: () -> Date`, `sleep: Sleep`, `random: (ClosedRange<Double>) -> Double`
  [`RealtimeSessionController.swift:RealtimeSessionController.init`].
- Shell inputs: `setDesired(active: Bool, user: AuthUser?) async`, `suspend() async`, `resume() async`,
  `syncRooms()`, `setRooms(_ rooms: [RoomSubscription])`, `setOpenRoom(_ room: RoomSubscription?)`,
  `ensureSubscribed(_ room: RoomSubscription) async`, `envelopes(for groupID: String) -> AsyncStream<RealtimeEnvelope>`,
  `sessionDidEnd()`, `desiredRooms() -> [String: Int]`, `noteEpoch(_ epoch: Int, for groupID: String)`
  [`RealtimeSessionController.swift:RealtimeSessionController`].
- Connection (`+Connection.swift`): `connect(fresh: Bool) async`, `scheduleRenewal(for token: String?, fresh: Bool)`,
  `scheduleReconnect(reason: String)`, `reconnect(reason: String) async`, `close(reason: String) async`,
  `catchUpOpenRoomWithoutConnection() async`, `adoptCachedEpochs() -> Set<String>`
  [`lily/Core/Realtime/RealtimeSessionController+Connection.swift:RealtimeSessionController.connect(fresh:)`].
- Routing (`+Routing.swift`): `reconcileSubscriptions()`, `subscribe(to channel: RealtimeChannel)`,
  `@discardableResult moveEpoch(of groupID: String, to epoch: Int?) -> Bool`,
  `removeGroupLocally(_ groupID: String, reason: String)`
  [`lily/Core/Realtime/RealtimeSessionController+Routing.swift:RealtimeSessionController.reconcileSubscriptions()`].

## Invariants

- A connect runs only when `isActive`, `user != nil` and `state` is neither `.connected` nor `.connecting`. No endpoint
  settles `state = .unavailable`; a `tokenProvider` that answers no token leaves the controller disconnected
  [`+Connection.swift:RealtimeSessionController.connectIfWanted(fresh:)`].
- One connect at a time: `connect(fresh:)` awaits any `connectionTask` in flight before making its own attempt; an
  attempt that a `close()` superseded while a connection is still wanted is followed by another in a task of its own.
  `connectionGeneration` moves on every attempt and every `close()`; `isSuperseded` is a moved generation or
  `Task.isCancelled` [`+Connection.swift:RealtimeSessionController.connect(fresh:)`, `+Connection.swift:RealtimeSessionController.isSuperseded(_:)`].
- State machine: `.disconnected` to `.connecting` once a token is in hand, to `.connected` when `transport.connect`
  returns. `RealtimeTransportError.unauthorized` sets `.disconnected`, reports `AppError.sessionExpired` once per
  session (skipped when `errorCenter.current?.error` already is it) and arms no reconnect; `.unavailable` sets
  `.unavailable`; any other error sets `.disconnected` and schedules a reconnect unless the attempt was superseded.
  `close()` moves `state` to `.disconnected` unless it is `.unavailable`, and calls `transport.disconnect()` only when
  it was `.connected` or `.connecting`
  [`+Connection.swift:RealtimeSessionController.open(_:generation:)`, `+Connection.swift:RealtimeSessionController.close(reason:)`, `+Connection.swift:RealtimeSessionController.reportExpiredSessionOnce()`].
- A first connect uses `tokenProvider.accessToken()`; every reconnect (`fresh: true`) uses `freshAccessToken()`. A
  fresh connect that gets no token increments `reconnectsWithoutToken` and backs off along the table while it is at
  most `AppConfig.Realtime.maxReconnectsWithoutToken`; a first connect's missing token arms nothing
  [`+Connection.swift:RealtimeSessionController.token(fresh:)`, `+Connection.swift:RealtimeSessionController.noteMissingToken(fresh:)`].
- Renewal follows `RenewalDelay` from the token's `exp` (`JWTClaims.expiration`), `lastExpiry` and `now()`; the
  previous `renewalTask` is cancelled; the task clears its slot before `reconnect(reason: "token renewal")`
  [`+Connection.swift:RealtimeSessionController.scheduleRenewal(for:fresh:)`].
- `scheduleReconnect` needs `isActive`, a user and no `reconnectTask` already armed; the delay is `backoff.next`. A
  connect that lands cancels a stale reconnect timer [`+Connection.swift:RealtimeSessionController.scheduleReconnect(reason:)`].
- After a connect: subscribe `.user(sub: user.id)`, reconcile rooms, then the resume protocol: `store.reload()`, bail
  unless still `.connected`, `syncRooms()`, `catchUp.catchUpMovedRooms(store.groups, openRoomID:, maxConcurrent: AppConfig.Chat.maxConcurrentCatchUps)`,
  `adoptCachedEpochs()`, and a second `catchUpRooms` for the rooms whose epoch moved
  [`+Connection.swift:RealtimeSessionController.runResumeProtocol()`].
- `resume()` after a suspend with no connection catches up the open room alone over REST and remembers the epoch its
  page answered; an `.active` to `.inactive` flip fetches nothing [`+Connection.swift:RealtimeSessionController.catchUpOpenRoomWithoutConnection()`].
- A user id change in `setDesired` closes ("session changed") and resets `knownEpochs`, `lastExpiry`, `backoff`,
  `reconnectsWithoutToken`, `reportedExpiredSession`; `suspend()` closes in a task of its own ("background");
  `sessionDidEnd()` clears user, wanted rooms and open room, resets, and closes ("sign-out")
  [`RealtimeSessionController.swift:RealtimeSessionController.setDesired(active:user:)`, `RealtimeSessionController.swift:RealtimeSessionController.sessionDidEnd()`].
- Desired set: the open room first, then `wantedRooms.prefix(AppConfig.Realtime.maxRoomSubscriptions)`, each at
  `knownEpochs[groupID] ?? room.epoch`. An epoch only grows (`noteEpoch` keeps the max)
  [`RealtimeSessionController.swift:RealtimeSessionController.desiredRooms()`, `RealtimeSessionController.swift:RealtimeSessionController.noteEpoch(_:for:)`].
- `reconcileSubscriptions()` is a no-op unless `.connected`; it unsubscribes rooms no longer desired and subscribes
  rooms whose epoch differs, except a room whose jittered resubscribe is pending keeps its old subscription
  [`+Routing.swift:RealtimeSessionController.reconcileSubscriptions()`].
- A stream that ends counts only if it is still the one held for its channel (`Subscription.id`). `subscribeRefused`
  on a room costs one `groupRepository.group(id:)` read: not a member or deleted drops the group locally; an epoch not
  newer than the refused one is not retried; a newer one resubscribes and catches that room up. `groupNotFound` drops
  the group. A refused user channel is only logged. Any other end closes ("connection lost") and schedules a reconnect
  [`+Routing.swift:RealtimeSessionController.streamEnded(_:id:error:)`, `+Routing.swift:RealtimeSessionController.refetchAndResubscribe(_:refusedEpoch:)`].
- A room envelope naming another group is dropped. Room events: `message` inserts into the cache and notes it in the
  store; a room that is not open is compacted and marked unread unless the caller sent it; `messageDeleted` marks the
  row; `memberLeft` for the caller drops the group, for anyone else resubscribes with a jitter of
  `random(0...min(memberCount * AppConfig.Realtime.resubscribeJitterPerMember, AppConfig.Realtime.resubscribeJitterMax))`;
  `groupDeleted` drops the group; `groupUpdated` applies to the store and adopts the epoch; `memberJoined` adopts the
  epoch; `tournamentChanged` and `matchUpdated` bump `tournamentChanges` and adopt the epoch; `membershipChanged`,
  `inboxItem` and `unknown` on a room are ignored
  [`+Routing.swift:RealtimeSessionController.route(_:from:)`, `+Routing.swift:RealtimeSessionController.applyRoomEvent(_:groupID:subscribedEpoch:)`, `+Routing.swift:RealtimeSessionController.resubscribeJittered(_:to:memberCount:)`].
- User-channel events: `membershipChanged` that ends the membership drops the group, otherwise notes the epoch, bumps
  `groupChanges` and reconciles; `inboxItem` goes to `inbox.apply`; everything else is ignored
  [`+Routing.swift:RealtimeSessionController.applyUserEvent(_:)`].
- `moveEpoch` writes the cache's room epoch when newer and answers whether the controller's knowledge moved;
  `removeGroupLocally` removes from the store, drops the cached room, marks it read, forgets its epoch and wanted
  entry, clears the open room if it was that one, cancels its pending resubscribe and unsubscribes
  [`+Routing.swift:RealtimeSessionController.moveEpoch(of:to:)`, `+Routing.swift:RealtimeSessionController.removeGroupLocally(_:reason:)`].
- `ensureSubscribed` waits out every pending resubscribe for the room in a loop before reconciling
  [`RealtimeSessionController.swift:RealtimeSessionController.ensureSubscribed(_:)`].

## Side Effects

- Transport: `connect`, `subscribe(to:)` (one stream task per channel), `disconnect`
  [`+Connection.swift:RealtimeSessionController.open(_:generation:)`, `+Routing.swift:RealtimeSessionController.subscribe(to:)`].
- REST through collaborators: `store.reload()`, `catchUp.catchUpMovedRooms` and `catchUpRooms`,
  `groupRepository.group(id:)` after a refused subscribe
  [`+Connection.swift:RealtimeSessionController.runResumeProtocol()`, `+Routing.swift:RealtimeSessionController.refetchAndResubscribe(_:refusedEpoch:)`].
- Writes: `ChatHistoryCache` (`insert`, `markDeleted`, `noteEpoch`, `compact`, `drop`), `MyGroupsStore` (`apply`,
  `replace`, `remove`, `noteMessage`), `UnreadCenter` (`markUnread`, `markRead`), `InboxStore.apply`,
  `ChangeTracker.recordChange` on both trackers, `ErrorCenter.report(.sessionExpired)`
  [`+Routing.swift:RealtimeSessionController.applyMessage(_:groupID:)`, `+Connection.swift:RealtimeSessionController.reportExpiredSessionOnce()`].
- Tasks and timers: `connectionTask`, `renewalTask`, `reconnectTask`, one `pendingResubscribes` task per group,
  detached close tasks in `suspend()` and `sessionDidEnd()`, a `Task { @MainActor }` per ended consumer stream; all
  waits go through the injected `sleep` [`RealtimeSessionController.swift:RealtimeSessionController.suspend()`].
- Logging under `.chat`, ids only: info for the connection opened, closed, reconnecting, renewing ("Chat connection
  opened to <host>", "Chat connection closed (<reason>)", "Chat reconnecting in <N>s (<reason>)"), "Realtime disabled;
  catch-up only", "Subscribed to <path>", "Epoch changed for group <id>: <old> -> <new>", "Group <id> dropped
  (<reason>)"; warning for every failure the screen does not show ("Chat connection failed", "No access token for the
  realtime connection", "Realtime connection refused the token", "Stream ended on <path>", "Dropped an envelope of
  another group", "Subscribe refused for group <id> at the current epoch", the stale-token and inside-margin renewals);
  debug for renewal scheduling, unsubscribes, jittered resubscribes, ignored and superseded events. Tests pin these as
  count plus fragment [`RealtimeSessionController+Connection.swift`, `RealtimeSessionController+Routing.swift`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Realtime`)
