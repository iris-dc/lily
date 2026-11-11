# Groups Models

Source: `lily/Features/Groups/Models/`

## Overview

Twenty-seven files of `nonisolated` value types, no logic that reaches outside the process. Three families: the wire
types decoded from Laurel's group, member, account, invite and moderation answers (`SportGroup`, `GroupMember`,
`GroupMembership`, `MembershipChange`, `Account`, `DeletionPlan`, `SentInvite`, `InviteCandidate`,
`ReportReceipt`, `BlockedUsers`, `UnbanReceipt`) and the request bodies that mirror the backend's DTOs key for key
(`CreateGroupPayload`, `UpdateGroupPayload`, `RoleChangePayload`, `SendInvitePayload`,
`ReportPayload`); the on-device rules the screens and their tests share (`GroupDraft` validation, `GroupAccess`,
`GroupDetailSection`); and small values for navigation and dialogs (`GroupScope`, `GroupConfirmation`,
`GroupDetailContext`, `GroupInfoDestination`, `DiscoverGroupsDestination`, `InviteTarget`, `ReportTarget`,
`RoomSubscription`, `EventGroupRef`, `Counterpart`). The repositories that move these over the wire are in
[Implementations](../Implementations/EGM.md); the protocols are in [Interfaces](../Interfaces/EGM.md).

## Interface

- `SportGroup: Identifiable, Hashable, Codable, Sendable` (the backend's `Group`; named so it does not shadow SwiftUI's
  `Group`): `id`, `name`, `description?`, `visibility: GroupVisibility`, `type: EventType?`, `ownerName`,
  `memberCount`, `maxMembers`, `channelEpoch`, `membersCanCreateEvents`, `membersCanInvite`, `lastMessageId?`,
  `lastMessageAt?`, `createdAt`, `deletedAt?`, `membership: GroupMembership?`, `kind: GroupKind`,
  `counterpart: Counterpart?`, `location: EventLocation?`. Computed: `isFull`, `isDirect`, `isTournamentRoom`,
  `isCommunity`, `isDeleted`, `isPublic`, `isMember`, `role: MemberRole?`, `hasUnread`, `lastActivityAt`,
  `ref: EventGroupRef`; `static mineOrder(_:_:)`, `isActive(on:calendar:)`, `distance(from:)`; copy builders
  `updatingMembership(_:memberCount:channelEpoch:)`, `dropping(_:)`, `keepingMembership(of:)`, `updating(with:)`,
  `markingDeleted(at:)`, `noting(_:) -> SportGroup?`, `keepingLaterLastMessage(of:)`
  [`lily/Features/Groups/Models/SportGroup.swift`:`SportGroup`].
- `SportGroup` captions: `caption(suffix:)`, `placeCaption(distance:) -> String?`, `avatarSymbol: String?`
  [`lily/Features/Groups/Models/SportGroup+Caption.swift`:`SportGroup.caption`].
- `GroupKind: WireNamedKind` with `group`, `direct`, `tournament`, `unknown(String)`; `known`, `wireName`;
  `init(wireName:)` and `isUnknown` are `WireNamedKind`'s defaults [`lily/Features/Groups/Models/GroupKind.swift`:`GroupKind`].
- `GroupVisibility: String` (`public`, `private`; `displayName`, `symbolName`)
  [`lily/Features/Groups/Models/GroupVisibility.swift`:`GroupVisibility`]; `GroupScope` (`mine`,
  `discover(query: String?, type: EventType?)`; `wireName`, `searchPrefix: String?`)
  [`lily/Features/Groups/Models/GroupScope.swift`:`GroupScope`]; `MemberRole: String` (`owner`, `admin`, `member`,
  `banned`; `isAdmin`, `displayName`; strict on purpose, like `GroupVisibility`: a permission ladder on both sides
  that the app also writes, and Laurel refuses an unknown name, so a new rung is a wire-version change) and
  `RoleChangePayload { role }` [`lily/Features/Groups/Models/MemberRole.swift`:`MemberRole`].
- Roster and membership: `GroupMember { userId, displayName, role, joinedAt }` with `id == userId` and
  `withRole(_:)`, `UnbanReceipt { unbanned }` [`lily/Features/Groups/Models/GroupMember.swift`:`GroupMember`];
  `GroupMembership { role, joinedAt, lastReadMessageId?, hasUnread }`
  [`lily/Features/Groups/Models/GroupMembership.swift`:`GroupMembership`]; `MembershipChange { groupId, change: Kind,
  role?, channelEpoch }` with `Kind: WireNamedKind` = `joined`, `left`, `removed`, `roleChanged` (`role_changed`),
  `unknown(String)` (`known`, `wireName`) and `endsMembership`
  [`lily/Features/Groups/Models/MembershipChange.swift`:`MembershipChange`]; `RoomSubscription { groupID, epoch }`
  with `init(group:)` [`lily/Features/Groups/Models/RoomSubscription.swift`:`RoomSubscription`].
- `GroupDraft: Equatable, Sendable, PlacePickingDraft`: `clientId` (let), `name`, `description`, `visibility`
  (default `.public`), `type`, `membersCanCreateEvents`, `membersCanInvite`, `locationName`,
  `coordinate: Coordinate?`, and the shared place bookkeeping `spotPickedOnMap`/`suggestedName` with
  `placeSuggestionQuery`, `apply(_:)` and `pickSpot(_:)` through `PlacePickingDraft`
  (`lily/Features/Events/Models/PlacePickingDraft.swift`; slice 3 of the creation-wizard plan, 2026-11-11);
  `init(clientId:)`, `init(editing: SportGroup)` (starts spot-picked: an edited name alone must not move the group);
  `enum Issue: CaseIterable` (`nameTooShort`, `nameTooLong`, `descriptionTooLong`,
  `locationNameMissing`, `locationNameTooLong`, `coordinateMissing`); `trimmedName`, `trimmedLocationName`,
  `trimmedDescription: String?`, `issues: [Issue]`, `isValid`, `location: EventLocation?`,
  `makeGroup(ownerName:now:) -> SportGroup` [`lily/Features/Groups/Models/GroupDraft.swift`:`GroupDraft`].
- Request bodies: `CreateGroupPayload(draft:)` { `clientGroupId`, `name`, `description?`, `visibility`, `type?`,
  `membersCanCreateEvents`, `membersCanInvite`, `location: CreateEventPayload.Location?` }
  [`lily/Features/Groups/Models/CreateGroupPayload.swift`:`CreateGroupPayload`]; `UpdateGroupPayload(draft:)` (the same
  set without `clientGroupId` and `visibility`) [`lily/Features/Groups/Models/UpdateGroupPayload.swift`:`UpdateGroupPayload`];
  `SendInvitePayload { userId }` [`lily/Features/Groups/Models/SentInvite.swift`:`SendInvitePayload`];
  `ReportPayload(target:reason:comment:)` { `targetType`, `targetId`, `groupId?`, `reason`, `comment?` }
  [`lily/Features/Groups/Models/Report.swift`:`ReportPayload`].
- `Account` (the answer of `GET /api/me`): `userId`, `isOperator`, `termsVersion`, `acceptedTermsVersion?`,
  `realtimeEndpoint: URL?`, `attachmentsEnabled`; the two terms fields stay decoded and ignored (2026-11-08:
  agreement is by use, stamped by the backend at creation) [`lily/Features/Groups/Models/Account.swift`:`Account`].
- `DeletionPlan` (the answer of `GET /api/me/deletion-plan`, the account-deletion contract §2): exactly five advisory
  `Int` counts — `groupsTransferring`, `groupsDeleted`, `eventsCancelled`, `entriesWithdrawn`, `tournamentsCancelled` —
  for the delete flow's summary copy; the execute path re-derives everything, so the preview may be stale. Same file:
  `DeletionSettle.isLanded(_: AppError) -> Bool`, the flow's inverted success check — true exactly for
  `.sessionExpired` (any 401; lily maps the status before reading a body) and `.userNotFound`, which mean the deletion
  landed [`lily/Features/Groups/Models/DeletionPlan.swift`:`DeletionPlan`].
- `GroupAccess: Equatable, Sendable`: `guest`, `canJoin`, `inviteOnly`, `member(MemberRole)`, `full`, `conversation`,
  `room`; `init(group:userID:)`; `isMember`, `canChat`, `canLeave`, `canEdit`, `canDelete`, `canChangeRoles`,
  `canSeeMembers(in:)`, `canReport(in:)`, `canCreateEvents(in:)`, `canInvite(in:)`, `canRemove(_:)`, `canBan(_:)`,
  `canCreatePolls(in:)`, `canPin(in:)` [`lily/Features/Groups/Models/GroupAccess.swift`:`GroupAccess`].
- Detail and dialogs: `GroupDetailSection` (`events`, `tournaments`, `members`; `static available(for:in:tournamentsEnabled:)`,
  `title`) [`lily/Features/Groups/Models/GroupDetailSection.swift`:`GroupDetailSection`]; `GroupConfirmation`
  (`leave`, `delete`, `remove(GroupMember)`, `ban(GroupMember)`; `id`, `title(groupName:)`, `buttonTitle`)
  [`lily/Features/Groups/Models/GroupConfirmation.swift`:`GroupConfirmation`]; `GroupDetailContext` (`standalone`,
  `fromChat`) [`lily/Features/Groups/Models/GroupDetailContext.swift`:`GroupDetailContext`]; `GroupInfoDestination
  { group }` [`lily/Features/Groups/Models/GroupInfoDestination.swift`:`GroupInfoDestination`]; the payload-less
  `DiscoverGroupsDestination` [`lily/Features/Groups/Models/DiscoverGroupsDestination.swift`:`DiscoverGroupsDestination`].
- Invites: `InviteCandidate { userId, displayName, via: InviteCandidateSource, viaName, isInvited }` with `id == userId`,
  `caption`, `markingInvited()`; `InviteCandidateSource: WireNamedKind` (`group`, `event`, `unknown(String)`; `known`,
  `wireName`) [`lily/Features/Groups/Models/InviteCandidate.swift`:`InviteCandidate`]; `SentInvite { id, groupId?, tournamentId?,
  inviteeUserId, inviteeName, status: InviteStatus, createdAt, expiresAt }`
  [`lily/Features/Groups/Models/SentInvite.swift`:`SentInvite`]; `InviteTarget` (`group(id:)`, `tournament(id:)`;
  `id`, `logName`, `logCategory`) [`lily/Features/Groups/Models/InviteTarget.swift`:`InviteTarget`].
- Moderation: `ReportReason: String` (`spam`, `harassment`, `inappropriate`, `other`; `displayName`); `ReportTarget
  { kind: Kind, id, groupID? }` with `Kind` = `message`, `group`, `tournament` (no `user`: the app files no user report;
  Laurel's `USER` stays unused), `logCategory` and the factories `message(id:groupID:)`, `group(id:)`,
  `tournament(id:)`; `groupID` stays optional for the wire's optional `groupId`; `ReportReceipt { id, createdAt }`;
  `BlockedUsers { blockedUserIds }` [`lily/Features/Groups/Models/Report.swift`:`ReportTarget`].
- Cross-feature values: `EventGroupRef { id, name, visibility, isDeleted }` with `isLinkable`, `isPrivate`
  [`lily/Features/Groups/Models/EventGroupRef.swift`:`EventGroupRef`]; `Counterpart { userId, displayName }` with
  `profile(context:) -> UserProfileDestination` [`lily/Features/Groups/Models/Counterpart.swift`:`Counterpart`].

## Invariants

- Every type is `nonisolated` and `Sendable`; answer types are `Codable` (`UnbanReceipt` is `Decodable`) and request
  bodies `Encodable`, all under the backend's key names, and absent
  optionals are omitted, never `null`: a blank description, a missing type and a group without a place stay out of
  `CreateGroupPayload`, a blank comment out of `ReportPayload` (`comment.nonBlankTrimmed`)
  [`lily/Features/Groups/Models/CreateGroupPayload.swift`:`CreateGroupPayload`].
- `SportGroup.init(from:)` is hand-written key for key only so a missing `kind` reads as `.group`; `Account.init(from:)`
  only so a missing `attachmentsEnabled` reads as `false` [`lily/Features/Groups/Models/SportGroup.swift`:`SportGroup.init(from:)`]
  [`lily/Features/Groups/Models/Account.swift`:`Account.init(from:)`].
- `GroupKind` travels as one string (`"group"`, `"direct"`, `"tournament"`); any other name is kept in `unknown`, so a
  newer backend's kind still decodes; the single-value `Codable` comes from `WireNamedKind`
  [`lily/Features/Groups/Models/GroupKind.swift`:`GroupKind.known`]
  [`lily/Core/Networking/Models/WireNamedKind.swift`:`WireNamedKind`].
- `SportGroup.role` is `nil` for a `banned` membership, so a banned marker never counts as `isMember`;
  `isCommunity` is `kind == .group`; `lastActivityAt` is `lastMessageAt ?? createdAt`; `mineOrder` is most recent
  activity first, ties by name then id (the contract with the backend's `MINE_ORDER`)
  [`lily/Features/Groups/Models/SportGroup.swift`:`SportGroup.mineOrder`].
- `noting(_:)` answers `nil` unless the message is later than `lastMessageAt`, so an older or repeated message changes
  nothing; `keepingLaterLastMessage(of:)` keeps the held copy's last message when it is later than the fresh one;
  `dropping(_:)` is one member fewer and `channelEpoch + 1`; `keepingMembership(of:)` keeps the stored copy's
  membership because a room-wide `group_updated` broadcast carries none
  [`lily/Features/Groups/Models/SportGroup.swift`:`SportGroup.noting`].
- Memberwise defaults: `maxMembers = AppConfig.Groups.maxMembers` (500), `channelEpoch = 1`, both `membersCan*` true,
  `kind = .group` [`lily/Features/Groups/Models/SportGroup.swift`:`SportGroup.init`]
  [`lily/Config/AppConfig+Groups.swift`:`AppConfig.Groups.maxMembers`].
- `GroupDraft.issues`, in form order, against `AppConfig.Groups` in UTF-16 units (`wireLength`): name within
  `3...60`, description at most 500, a place name required only when `visibility == .public`, at most
  `locationNameMaxLength` (= `AppConfig.Events.Creation.locationNameMaxLength`), and `coordinateMissing` when a place
  is named without a coordinate; `isValid` is `issues.isEmpty`; `location` is `nil` unless both name and coordinate are
  set [`lily/Features/Groups/Models/GroupDraft.swift`:`GroupDraft.issues`]
  [`lily/Config/AppConfig+Groups.swift`:`AppConfig.Groups.nameLength`].
- `GroupDraft.clientId` is chosen once per draft (a lower-cased `UUID`) and becomes the group's id: `makeGroup` uses it
  and `CreateGroupPayload.clientGroupId` sends it, so a repeated create finds its group; `init(editing:)` reuses the
  group's id [`lily/Features/Groups/Models/GroupDraft.swift`:`GroupDraft.clientId`].
- `makeGroup(ownerName:now:)` answers `memberCount: 1` with an `owner` membership joined at `now`
  [`lily/Features/Groups/Models/GroupDraft.swift`:`GroupDraft.makeGroup`].
- `UpdateGroupPayload` leaves `visibility` out (immutable once created) and a missing `location` clears the group's
  place, since the body is the whole editable state [`lily/Features/Groups/Models/UpdateGroupPayload.swift`:`UpdateGroupPayload`]
  [`lily/Features/Groups/Models/GroupVisibility.swift`:`GroupVisibility`].
- `GroupAccess.init(group:userID:)` decides in order: no `userID` is `guest`; a direct group the caller is in is
  `conversation`; a tournament room or an unknown kind the caller is in is `room`; a role is `member(role)`; then
  `full`, then `canJoin` for a public group, else `inviteOnly`
  [`lily/Features/Groups/Models/GroupAccess.swift`:`GroupAccess.init`].
- `GroupAccess` rules: `canLeave` only for a member who is not the owner; `canEdit` for `isAdmin` roles; `canDelete`
  and `canChangeRoles` for the owner; `canSeeMembers` for members and for any signed-in caller of a public group;
  `canReport` is `canSeeMembers` minus the owner; `canCreateEvents`/`canInvite` for admins always and members when the
  group's flag allows; `canRemove`/`canBan`: owner on member and admin, admin on member, nobody on the owner;
  `canCreatePolls` for members of a non-direct, known kind; `canPin` for either side of a conversation or an admin of a
  known kind [`lily/Features/Groups/Models/GroupAccess.swift`:`GroupAccess.canRemove`].
- `GroupDetailSection.available`: `events` always, `tournaments` while `tournamentsEnabled` (default
  `AppConfig.FeatureFlags.tournaments`) and the group is public or the caller is in it, `members` when
  `access.canSeeMembers(in:)` [`lily/Features/Groups/Models/GroupDetailSection.swift`:`GroupDetailSection.available`].
- `GroupScope.wireName` is `"mine"` or `"public"`; `searchPrefix` trims and is `nil` for `.mine` and for a blank
  query, which is a browse [`lily/Features/Groups/Models/GroupScope.swift`:`GroupScope.searchPrefix`].
- `MemberRole.isAdmin` is `owner || admin` [`lily/Features/Groups/Models/MemberRole.swift`:`MemberRole.isAdmin`];
  `MembershipChange.Kind.roleChanged` is the wire string `"role_changed"`, and `endsMembership` is `left || removed`
  (a ban arrives as `removed`; a kind this build does not know decodes as `unknown(name)` and ends nothing)
  [`lily/Features/Groups/Models/MembershipChange.swift`:`MembershipChange.endsMembership`]. `InviteCandidate.caption` is
  "In <viaName>" for `group`, "Played <viaName>" for `event` and the `viaName` alone for an unknown source
  [`lily/Features/Groups/Models/InviteCandidate.swift`:`InviteCandidate.caption`]. `MemberRole` and `GroupVisibility`
  decode strictly: an unknown value fails the payload, by design.
- `ReportTarget.group`/`.tournament` carry their own id as `groupID`, `.message` carries its room, `.user` none;
  `logCategory` is `.tournaments` for a tournament and `.groups` otherwise, as is `InviteTarget.logCategory`
  [`lily/Features/Groups/Models/Report.swift`:`ReportTarget.logCategory`]
  [`lily/Features/Groups/Models/InviteTarget.swift`:`InviteTarget.logCategory`].
- `EventGroupRef.isLinkable` is public and not deleted [`lily/Features/Groups/Models/EventGroupRef.swift`:`EventGroupRef.isLinkable`];
  `GroupConfirmation.id` is the value itself [`lily/Features/Groups/Models/GroupConfirmation.swift`:`GroupConfirmation.id`];
  `InviteCandidate.isInvited` is `private(set)` and only `markingInvited()` sets it
  [`lily/Features/Groups/Models/InviteCandidate.swift`:`InviteCandidate.markingInvited`].

## Side Effects

- No network, disk, logging or shared state: every function is a pure value transform.
- `GroupDraft.init(clientId:)` generates a `UUID()` when none is given
  [`lily/Features/Groups/Models/GroupDraft.swift`:`GroupDraft.init`]; `SportGroup.isActive(on:calendar:)` reads
  `Calendar.current` by default [`lily/Features/Groups/Models/SportGroup.swift`:`SportGroup.isActive`].
- Localised copy is read through `AppBranding` in `SportGroup.caption`/`placeCaption`, `GroupVisibility.displayName`,
  `MemberRole.displayName`, `ReportReason.displayName`, `GroupDetailSection.title`, `GroupConfirmation.title`/
  `buttonTitle` and `InviteCandidate.caption`; symbols through `DesignTokens.Symbols` in `GroupVisibility.symbolName`
  and `SportGroup.avatarSymbol` [`lily/Features/Groups/Models/SportGroup+Caption.swift`:`SportGroup.caption`].
- `Counterpart.profile(context:)` builds a `UserProfileDestination` navigation value
  [`lily/Features/Groups/Models/Counterpart.swift`:`Counterpart.profile`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Groups`, for
  example `GroupModelsTests`, `GroupDraftTests`, `GroupAccessTests`, `GroupPayloadTests`, `GroupScopeTests`,
  `GroupDetailSectionTests`, `GroupConfirmationTests`, `AccountCodingTests`, `DeletionPlanTests` (with
  `DeletionSettleTests`), `SportGroupCaptionTests`).
