# Realtime Models

Source: `lily/Core/Realtime/Models/`

## Overview

Plain values of the realtime layer: channel names, connection states, the decoded event envelope, the transport
errors, and the two pieces of timing arithmetic (reconnect backoff and token renewal). Every type is `nonisolated` and
`Sendable`; none performs I/O. Thresholds come from `AppConfig.Realtime` (`lily/Config/`) and are cited by name.

## Interface

- `nonisolated struct Backoff: Equatable, Sendable`: `let table: [TimeInterval]`, `let jitter: Double`,
  `private(set) var attempt`; `init(table: = AppConfig.Realtime.reconnectBackoffSeconds, jitter: = AppConfig.Realtime.reconnectJitter)`;
  `mutating func next(random: (ClosedRange<Double>) -> Double) -> TimeInterval`; `mutating func reset()`
  [`lily/Core/Realtime/Models/Backoff.swift:Backoff`].
- `nonisolated enum RealtimeChannel: Hashable, Sendable`: `.room(groupID: String, epoch: Int)`, `.user(sub: String)`;
  `var path: String` [`lily/Core/Realtime/Models/RealtimeChannel.swift:RealtimeChannel`].
- `nonisolated enum RealtimeConnectionState: Hashable, Sendable`: `.unavailable`, `.disconnected`, `.connecting`,
  `.connected` [`lily/Core/Realtime/Models/RealtimeConnectionState.swift:RealtimeConnectionState`].
- `nonisolated enum RealtimeEnvelope: Hashable, Sendable, Decodable`: `.message(ChatMessage)`,
  `.messageDeleted(groupID:id:)`, `.memberJoined(groupID:member:memberCount:channelEpoch:)` (member is a
  `GroupMember`), `.memberLeft(groupID:userID:channelEpoch:memberCount:)`, `.groupUpdated(SportGroup)`,
  `.groupDeleted(groupID:)`, `.membershipChanged(MembershipChange)`, `.inboxItem(InboxItem)`,
  `.tournamentChanged(TournamentChange)`, `.matchUpdated(TournamentMatch)`, `.unknown(type: String)`; nested
  `enum Kind: String` with the wire names `message`, `message_deleted`, `member_joined`, `member_left`,
  `group_updated`, `group_deleted`, `membership_changed`, `inbox_item`, `tournament_changed`, `match_updated`;
  `var groupID: String?`; `var channelEpoch: Int?` [`lily/Core/Realtime/Models/RealtimeEnvelope.swift:RealtimeEnvelope`].
- `nonisolated enum RealtimeTransportError: Error, Hashable, Sendable`: `.unauthorized`, `.subscribeRefused`,
  `.unavailable`, `.connectionLost` [`lily/Core/Realtime/Models/RealtimeTransportError.swift:RealtimeTransportError`].
- `nonisolated struct RenewalDelay: Equatable, Sendable`: `enum Reason { scheduled, staleToken, insideMargin }`,
  `let bound: TimeInterval`, `let reason: Reason`; `init(expiry: Date?, lastExpiry: Date?, now: Date, fresh: Bool)`;
  `func seconds(backingOff backoff: inout Backoff, random: (ClosedRange<Double>) -> Double) -> TimeInterval`
  [`lily/Core/Realtime/Models/RenewalDelay.swift:RenewalDelay`].

## Invariants

- `Backoff.init` has `precondition(!table.isEmpty)`. `next` returns
  `table[min(attempt, table.count - 1)] * (1 + random(-jitter...jitter))` and increments `attempt`, so the wait walks
  the table once per attempt and stays on its last entry; `reset()` returns `attempt` to 0
  [`Backoff.swift:Backoff.next(random:)`, `Backoff.swift:Backoff.reset()`].
- `RealtimeChannel.path` is `"\(AppConfig.Realtime.roomsNamespace)/<groupID>/<epoch>"` for a room and
  `"\(AppConfig.Realtime.usersNamespace)/<sub>"` for a user [`RealtimeChannel.swift:RealtimeChannel.path`].
- `RealtimeEnvelope.init(from:)` reads `type`; a value outside `Kind` decodes as `.unknown(type:)` and never throws
  for an unknown type. Coding keys are `type, message, groupId, messageId, member, memberCount, channelEpoch, userId,
  group, item, match`. `message` decodes a `ChatMessage` under `message`; `message_deleted` reads `groupId` and
  `messageId`; `inbox_item` reads `item`; `member_joined` reads `groupId`, `member`, `memberCount`, `channelEpoch`;
  `member_left` reads `groupId`, `userId`, `channelEpoch`, `memberCount`; `group_updated` reads `group`;
  `group_deleted` reads `groupId`; `membership_changed` and `tournament_changed` decode their payload from the
  envelope itself (fields beside `type`; a `membership_changed` whose `change` this build does not know still decodes,
  `MembershipChange.Kind` being a `WireNamedKind`); `match_updated` reads `match`
  [`RealtimeEnvelope.swift:RealtimeEnvelope.init(from:)`].
- `RealtimeEnvelope.groupID` is `nil` for `.inboxItem` and `.unknown`; a tournament event answers the tournament id
  (its room). `channelEpoch` is non-nil only for `.memberJoined`, `.memberLeft`, `.groupUpdated`
  (`group.channelEpoch`), `.membershipChanged` and `.tournamentChanged`
  [`RealtimeEnvelope.swift:RealtimeEnvelope.groupID`, `RealtimeEnvelope.swift:RealtimeEnvelope.channelEpoch`].
- `RenewalDelay.bound` is `min(expiry - now - AppConfig.Realtime.reconnectBeforeExpiry, AppConfig.Realtime.maxConnectionAge)`,
  or `maxConnectionAge` alone when no expiry is known. `reason` is `.staleToken` when `fresh` and
  `expiry <= lastExpiry`, `.insideMargin` when the expiry-bound wait is `<= 0`, else `.scheduled`
  [`RenewalDelay.swift:RenewalDelay.init(expiry:lastExpiry:now:fresh:)`].
- `RenewalDelay.seconds(backingOff:random:)`: a `.scheduled` renewal resets the backoff and returns `bound`; the other
  two reasons return `max(bound, backoff.next(random:))`, so a renewal never runs before the expiry-bound moment and a
  token that would renew at once falls into the backoff table instead
  [`RenewalDelay.swift:RenewalDelay.seconds(backingOff:random:)`].

## Side Effects

- None (pure value types; no I/O, no logging).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Realtime`)
