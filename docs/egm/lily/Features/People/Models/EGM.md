# People Models

Source: `lily/Features/People/Models/`

## Overview

The wire and navigation values of the People feature: `UserProfile` (another person with their bio and what the caller
shares with them), `GroupSummary` (a group as a profile's "Groups in common" row shows it), `EventSummary` (a game as a
"Games together" row shows it), `TournamentSummary` (a tournament as a "Tournaments together" row shows it),
`StartConversationPayload` (the body that opens a direct conversation), `UserProfileDestination` (the value pushed
from wherever a person is named) and `Tombstone` (the deletion contract's one mapping from the wire's `deleted` flag
to the localized "Deleted user" name and the fixed mark).
All are `nonisolated`, `Sendable` values that keep the backend's key names.

## Interface

- `UserProfile: Hashable, Codable, Sendable` `[lily/Features/People/Models/UserProfile.swift:UserProfile]`: `userId`,
  `displayName`, `bio: String?`, `sharedGroups: [GroupSummary]`, `sharedEvents: [EventSummary]`,
  `sharedTournaments: [TournamentSummary]`; `init(userId:displayName:bio: = nil, sharedGroups:sharedEvents: = [],
  sharedTournaments: = [])` and a hand-written `init(from:)`.
- `EventSummary: Identifiable, Hashable, Codable, Sendable` `[lily/Features/People/Models/EventSummary.swift:EventSummary]`:
  `id`, `title`, `type: EventType`, `startsAt: Date`, `locationName`; `init(_ event: SportEvent)`; `caption`
  ("Football · 2 Oct 2026 · Tempelhofer Feld": the type, the day in `LilyTheme.DateStyles.date`, the place, joined by
  `AppBranding.Groups.caption`).
- `TournamentSummary: Identifiable, Hashable, Codable, Sendable`
  `[lily/Features/People/Models/TournamentSummary.swift:TournamentSummary]`: `id`, `name`, `type: EventType`,
  `status: TournamentStatus`, `startsAt: Date`; `init(_ tournament: Tournament)`; `caption` ("Football · Completed ·
  4 Oct 2026"); `destination: TournamentDestination` (`id` and `name` alone, no preview: the detail fetches it).
- `GroupSummary: Identifiable, Hashable, Codable, Sendable` `[lily/Features/People/Models/GroupSummary.swift:GroupSummary]`:
  `id`, `name`, `visibility: GroupVisibility`, `type: EventType?` (absent means any sport), `memberCount`;
  `init(id:name:visibility:type: = nil, memberCount:)` and `init(_ group: SportGroup)`; `caption`
  (`AppBranding.Groups.groupCaption(memberCount:type:)`, "34 members · Football"); `ref: EventGroupRef`, the
  destination that fetches the group and shows its detail.
- `StartConversationPayload: Encodable, Equatable, Sendable`
  `[lily/Features/People/Models/StartConversationPayload.swift:StartConversationPayload]`: `userId`; the body of
  `POST /api/conversations`.
- `UserProfileDestination: Hashable, Sendable` `[lily/Features/People/Models/UserProfileDestination.swift:UserProfileDestination]`:
  `userId`, `displayName` (what the screen shows until the profile answers), `context: GroupDetailContext` (default
  `.standalone`; `.fromChat` when the conversation with the person is one Back away, where "Message" would only push
  that chat again).
- `Tombstone` `[lily/Features/People/Models/Tombstone.swift:Tombstone]`: `displayName(_ snapshot: String,
  deleted: Bool?) -> String` (the localized `AppBranding.DeletedUser.name` exactly when `deleted == true`, else the
  snapshot — an absent flag, an old backend, reads as not deleted) and `symbol` (`DesignTokens.Symbols.deletedUser`,
  `person.slash`): the one mapping for the deletion contract's flag on its four representations (message sender,
  event host, tournament organizer, entry member), so features never word the tombstone themselves.

## Invariants

- `UserProfile.sharedGroups`, `sharedEvents` and `sharedTournaments` never hold a group, game or tournament the caller is
  not in, and the caller's own id answers their own (doc comment; the repositories enforce it); the two history lists
  come latest first from the backend and are shown as received `[lily/Features/People/Models/UserProfile.swift:UserProfile]`.
- `UserProfile.init(from:)` exists for one reason: `sharedEvents` and `sharedTournaments` default to `[]` when the key
  is missing, so a backend before the shared history still decodes; `bio` is `decodeIfPresent`
  `[lily/Features/People/Models/UserProfile.swift:UserProfile.init(from:)]`.
- `GroupSummary.ref` always answers `isDeleted: false` `[lily/Features/People/Models/GroupSummary.swift:GroupSummary.ref]`.
- Every type is `nonisolated`, `Sendable` and `let`-only; `StartConversationPayload` is encode-only
  `[lily/Features/People/Models/StartConversationPayload.swift:StartConversationPayload]`.

## Side Effects

- None: value types.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/People`; `RemoteUserRepositoryTests.theContractProfileDecodes` and
  `theHistoryRowsCaptionAndLinkFromTheSummaries` pin the shapes and captions; `TombstoneTests` pins the flag's four
  decode sites and the helper's mapping).
