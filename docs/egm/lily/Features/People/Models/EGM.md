# People Models

Source: `lily/Features/People/Models/`

## Overview

The wire and navigation values of the People feature: `UserProfile` (another person with the groups the caller shares
with them), `GroupSummary` (a group as a profile's "Groups in common" row shows it), `StartConversationPayload` (the
body that opens a direct conversation) and `UserProfileDestination` (the value pushed from wherever a person is named).
All are `nonisolated`, `Sendable` values that keep the backend's key names.

## Interface

- `UserProfile: Hashable, Codable, Sendable` `[lily/Features/People/Models/UserProfile.swift:UserProfile]`: `userId`,
  `displayName`, `sharedGroups: [GroupSummary]`.
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

## Invariants

- `UserProfile.sharedGroups` never holds a group the caller is not in, and the caller's own id answers their own
  groups (doc comment; the repositories enforce it) `[lily/Features/People/Models/UserProfile.swift:UserProfile]`.
- `GroupSummary.ref` always answers `isDeleted: false` `[lily/Features/People/Models/GroupSummary.swift:GroupSummary.ref]`.
- Every type is `nonisolated`, `Sendable` and `let`-only; `StartConversationPayload` is encode-only
  `[lily/Features/People/Models/StartConversationPayload.swift:StartConversationPayload]`.

## Side Effects

- None: value types.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/People`).
