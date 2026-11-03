# Groups Implementations

Source: `lily/Features/Groups/Implementations/`

## Overview

The concrete types behind the protocols in [Interfaces](../Interfaces/EGM.md). Four `Remote*` repositories build an
`APIRequest` from `AppConfig.API.Paths` and call `client.send(request, failingWith:)` with a per-route fallback
`AppError`; they perform no retry of their own (the one `TRY_AGAIN` repeat belongs to the callers in
[ViewModels](../ViewModels/EGM.md)) and emit no log lines. Four `Mock*` repositories replay Laurel's refusals and
orders in memory, over six fixture communities around Berlin, one direct conversation with Marta and the fixture
tournament rooms, so the simulator and the UI tests run without a backend. `MockInviteCandidatePool` and
`MockInviteLedger` are shared by the group and tournament invite mocks. The value types they move are in
[Models](../Models/EGM.md).

## Interface

- `RemoteGroupRepository: GroupRepository`, `init(client: any APIClient, identity: any IdentityProvider)`; a private
  `roster(at:)` serves `members` and `bans`; a private `GroupScope` extension supplies `takesPosition` (true only for a
  Discover browse without a search prefix) and `queryItems` (`scope`, and for Discover `q`, `type`, `limit`)
  [`lily/Features/Groups/Implementations/RemoteGroupRepository.swift`:`RemoteGroupRepository`].
- `RemoteInviteRepository: InviteRepository`, `RemoteMeRepository: MeRepository`,
  `RemoteModerationRepository: ModerationRepository`, each `init(client: any APIClient)`; the moderation one funnels
  its three block routes through a private `blockList(_ request: APIRequest<BlockedUsers>)`
  [`lily/Features/Groups/Implementations/RemoteModerationRepository.swift`:`RemoteModerationRepository.blockList`].
- `MockGroupRepository: GroupRepository` (`final class`), `init(identity: any IdentityProvider, logger: any Logging,
  now: @escaping () -> Date = { .now })`; internal state `groups: [SportGroup]`, `rosters: [String: [GroupMember]]`,
  `hiddenConversationIDs: Set<String>`; extra entry points for the other mocks: `admit(id:) throws -> SportGroup`
  (the invite-acceptance path, private groups included), `markRead(id:messageID:) throws -> String`,
  `noteMessage(_:in:)`, `membershipOnJoin(of:)`, `find(_:)`, `roster(of:)` (`rosters[groupID] ?? []`, the one roster read,
  banned rows included), `store(_:)`
  [`lily/Features/Groups/Implementations/MockGroupRepository.swift`:`MockGroupRepository.admit`].
- `MockGroupRepository` extensions: `displayName(ofUser:)`, `startDirect(with:name:)`, `hideConversation(id:)`,
  `unhideConversation(id:)` [`lily/Features/Groups/Implementations/MockGroupRepository+Direct.swift`:`MockGroupRepository.startDirect`];
  `discover(prefix:type:near:) -> Page<SportGroup>` with a private `SportGroup.matches(prefix:type:)`
  [`lily/Features/Groups/Implementations/MockGroupRepository+Discover.swift`:`MockGroupRepository.discover`];
  `registerRoom(for:memberCount:)`, `syncRoom(for:memberCount:)`, `admitToRoom(id:)`, `leaveRoom(id:userID:)`
  [`lily/Features/Groups/Implementations/MockGroupRepository+Tournaments.swift`:`MockGroupRepository.registerRoom`].
- `nonisolated enum MockGroupFixtures`: ids `kickersID`, `runnersID`, `padelID`, `basketballID`, `volleyID`,
  `climbingID` (`"mock-group-<name>"`), `conversationCounterpart` (Marta) and `martaConversationID`;
  `make(now:) -> [SportGroup]` (the six templates, Marta's conversation and `MockTournamentFixtures.rooms(now:)`),
  `roster(for:now:)`, `memberID(for:)` (`"mock-user-<lowercased name>"`), `directConversationID(for:)`
  (`"mock-dm-<userID>"`), `ref(for:) -> EventGroupRef?`
  [`lily/Features/Groups/Implementations/MockGroupFixtures.swift`:`MockGroupFixtures.make`]; the `Template` and
  `Place` structs that describe a fixture
  [`lily/Features/Groups/Implementations/MockGroupFixtures+Template.swift`:`MockGroupFixtures.Template`].
- The six fixtures: Kreuzberg Kickers (public, football, caller a member, 34 members, unread), Tempelhof Runners
  (public, running, caller an admin), Sunday Padel Crew (private, padel, caller the owner; Priya banned), Berlin
  Basketball (public, no role), Spree Volley (public, 12 of 12, full), Climbing Buddies (private, no role); each with a
  Berlin place [`lily/Features/Groups/Implementations/MockGroupFixtures.swift`:`MockGroupFixtures.templates`].
- `MockInviteCandidatePool { groups: MockGroupRepository, now }` with
  `candidates(excludingGroup: String, seen:isInvited:) async throws -> [InviteCandidate]`; `MockInviteLedger` with
  `isInvited(_:into:)` (`existing(for:into:) != nil`) and `send(to:among:into:now:logger:) throws -> SentInvite`
  [`lily/Features/Groups/Implementations/MockInviteCandidatePool.swift`:`MockInviteLedger.send`].
- `MockInviteRepository: InviteRepository`, `init(groups: MockGroupRepository, identity:, logger:, now:)`;
  `candidates(groupID:)` and `invite(groupID:userID:)` build the list once each through the private `candidates(in:)`
  after one `requireInviteRights(in:)`
  [`lily/Features/Groups/Implementations/MockInviteRepository.swift`:`MockInviteRepository`];
  `MockMeRepository: MeRepository`, `init(identity:, logger:, now:, termsPending: Bool = false)`, `owesTerms`
  [`lily/Features/Groups/Implementations/MockMeRepository.swift`:`MockMeRepository`];
  `MockModerationRepository: ModerationRepository`, `init(logger:, now:)` (`report`, `blocks`, `block`; no unblock)
  [`lily/Features/Groups/Implementations/MockModerationRepository.swift`:`MockModerationRepository`].
- Fixture dates are built from `TimeInterval.hour` and `.day` (`lily/Core/System/TimeInterval+Units.swift`): days ago
  and hours ago times the unit [`lily/Features/Groups/Implementations/MockGroupFixtures.swift`:`MockGroupFixtures.makeGroup`].

## Invariants

- Every repository is a `final class` under the target's main-actor default; only `MockGroupFixtures` and its
  `Template` extension are `nonisolated` [`lily/Features/Groups/Implementations/MockGroupFixtures.swift`:`MockGroupFixtures`].
- Remote fallbacks: group reads fail with `.groupsUnavailable`, `create` with `.groupCreationFailed`, the other group
  writes with `.groupActionFailed`; invite routes with `.inviteUnavailable`; `report` with `.reportFailed`; `me`,
  `acceptTerms` and the block routes with `.unknown`
  [`lily/Features/Groups/Implementations/RemoteGroupRepository.swift`:`RemoteGroupRepository.create`].
- Remote decoding: `members`/`bans` decode `Page<GroupMember>` and answer `.items`, `unban` decodes `UnbanReceipt` and
  discards it, `setRole` decodes `GroupMember`, the block routes decode `BlockedUsers` into a `Set`
  [`lily/Features/Groups/Implementations/RemoteGroupRepository.swift`:`RemoteGroupRepository.roster`].
- `RemoteGroupRepository.leave` throws `AppError.notAMember` without a current user, else delegates to
  `remove(id:userID:)` with the caller's id; a position goes out only for a Discover browse, `cursor` only when present,
  and Discover always sends `limit = AppConfig.Groups.discoverPageSize` (50)
  [`lily/Features/Groups/Implementations/RemoteGroupRepository.swift`:`GroupScope.takesPosition`]
  [`lily/Config/AppConfig+Groups.swift`:`AppConfig.Groups.discoverPageSize`].
- Mock readability gate `readable(id)`: an unknown or deleted id, or a private group the caller is not in, throws
  `AppError.groupNotFound`; `requireGroupRoute` throws `.insufficientRole` for a direct conversation or a tournament
  room (unknown kinds pass) [`lily/Features/Groups/Implementations/MockGroupRepository.swift`:`MockGroupRepository.readable`].
- Mock role rules: `update`, `bans`, `unban` need `isAdmin`; `delete` needs the owner; `remove` needs
  `GroupAccess.canRemove(target.role)`; `setRole(.banned)` needs `canBan`, other roles `canChangeRoles`; a target not on
  the roster throws `.notAMember` [`lily/Features/Groups/Implementations/MockGroupRepository.swift`:`MockGroupRepository.setRole`].
- Mock join and leave: a member joining again is answered unchanged; a private group throws `.groupNotFound`, a full
  one `.groupFull`; leaving without a membership throws `.notAMember`, as the owner `.ownerCannotLeave`; `remove` of
  the caller's own id is a leave [`lily/Features/Groups/Implementations/MockGroupRepository.swift`:`MockGroupRepository.join`].
- Mock orders: `.mine` is the caller's live groups minus hidden conversations in `SportGroup.mineOrder`; `members` is
  owner, admins, then `joinedAt`, without banned rows, and throws `.sessionExpired` for a guest; Discover offers only
  public, live communities, by name with a prefix, nearest first with a position (no distance last, ties newest), else
  newest first [`lily/Features/Groups/Implementations/MockGroupRepository+Discover.swift`:`MockGroupRepository.discoverOrder`].
- Mock idempotency: a `create` whose `clientId` is an existing id replays that group when the draft equals the stored
  one, is refused with `.createIdReused` when it differs (`update` stores the new draft), and is refused with
  `.groupCreationFailed` when the id names a deleted group (Laurel's `GROUP_ID_TAKEN`: the tombstone keeps the id, so
  nothing replays it); `startDirect` replays (and
  unhides) the pair's conversation; `registerRoom` and `admitToRoom` are no-ops when already done; a pending invite for
  the same target and user is replayed [`lily/Features/Groups/Implementations/MockGroupRepository.swift`:`MockGroupRepository.create`]
  [`lily/Features/Groups/Implementations/MockInviteCandidatePool.swift`:`MockInviteLedger.isInvited`].
- Mock bookkeeping: `markRead` keeps a monotonic marker and recomputes `hasUnread`; banning a live member drops the
  count through `dropping(_:)` before the roster row changes; only direct conversations can be hidden
  [`lily/Features/Groups/Implementations/MockGroupRepository.swift`:`MockGroupRepository.markRead`].
- Mock invite refusals, in order: no user `.sessionExpired`; invisible group `.groupNotFound`; not `canChat`
  `.notAMember`; not `canInvite` `.insufficientRole`; self `.alreadyMember`; a roster member `.cannotInvite` when banned
  else `.alreadyMember`
  [`lily/Features/Groups/Implementations/MockInviteRepository.swift`:`MockInviteRepository.invite`]; not a candidate
  `.userNotFound` [`lily/Features/Groups/Implementations/MockInviteCandidatePool.swift`:`MockInviteLedger.send`].
- Mock candidates are the live members of the caller's other non-direct groups and rooms, then the hosts of the mock
  event feed, deduplicated through `seen` (seeded with the target roster and the caller), sorted by display name
  [`lily/Features/Groups/Implementations/MockInviteCandidatePool.swift`:`MockInviteCandidatePool.candidates`].
- `MockMeRepository.me()` throws `.sessionExpired` without a user, marks the Apple mock user as operator (mirroring the
  backend's operators group; lily has no operator UI), leaves
  `acceptedTermsVersion` nil while `owesTerms`, and `acceptTerms` clears `owesTerms` for the run;
  `MockModerationRepository.block` throws `.blockLimitReached` at `AppConfig.Moderation.maxBlocks` (500) blocked,
  except for a user already in the list, who is answered the list unchanged
  [`lily/Features/Groups/Implementations/MockMeRepository.swift`:`MockMeRepository.me`]
  [`lily/Config/AppConfig+Moderation.swift`:`AppConfig.Moderation.maxBlocks`].
- Mock state is built once in `init` from one `now()` read and lives in instance properties; it resets only with a
  new instance [`lily/Features/Groups/Implementations/MockGroupRepository.swift`:`MockGroupRepository.init`].

## Side Effects

- Group routes: `GET /api/groups?scope=mine|public[&q=][&type=]&limit=50[&lat=&lon=][&cursor=]`,
  `GET /api/groups/{id}`, `POST /api/groups` (`CreateGroupPayload`), `PUT /api/groups/{id}` (`UpdateGroupPayload`),
  `DELETE /api/groups/{id}`, `POST /api/groups/{id}/members`, `DELETE /api/groups/{id}/members/{userID}`,
  `PUT /api/groups/{id}/members/{userID}` (`RoleChangePayload`), `GET /api/groups/{id}/members`,
  `GET /api/groups/{id}/bans`, `DELETE /api/groups/{id}/bans/{userID}`
  [`lily/Features/Groups/Implementations/RemoteGroupRepository.swift`:`RemoteGroupRepository.groups`]
  [`lily/Config/AppConfig+Groups.swift`:`AppConfig.API.Paths.groups`].
- Invite routes: `GET /api/groups/{id}/invitees`, `POST /api/groups/{id}/invites` (`SendInvitePayload`)
  [`lily/Features/Groups/Implementations/RemoteInviteRepository.swift`:`RemoteInviteRepository.invite`]
  [`lily/Config/AppConfig+Groups.swift`:`AppConfig.API.Paths.groupInvites`].
- Account and moderation routes: `GET /api/me`, `PUT /api/me/terms` (`TermsAcceptancePayload`), `POST /api/reports`
  (`ReportPayload`), `GET /api/blocks`, `PUT /api/blocks/{userID}`, `DELETE /api/blocks/{userID}`
  [`lily/Features/Groups/Implementations/RemoteMeRepository.swift`:`RemoteMeRepository.acceptTerms`]
  [`lily/Features/Groups/Implementations/RemoteModerationRepository.swift`:`RemoteModerationRepository.blocks`]
  [`lily/Config/AppConfig+Moderation.swift`:`AppConfig.API.Paths.reports`].
- Mock state mutation: `groups` appended by create, `startDirect`, `registerRoom` and replaced through `store(_:)` by
  every other write except `syncRoom(for:memberCount:)`, which rewrites the room in place; `rosters` rewritten by create, `registerRoom`, `startDirect`, `remove`, `unban`, `leaveRoom`,
  `setRole`; `hiddenConversationIDs` by hide/unhide; the ledger's `sent` map and `sentCount`; `owesTerms`; `blocked`; `drafts` by
  create and update (a repeated create with other details is `.createIdReused`)
  [`lily/Features/Groups/Implementations/MockGroupRepository.swift`:`MockGroupRepository.store`].
- Logging, ids only, under `.groups`: debug for `groups(in:)`, candidates (from `candidates(groupID:)` only, never on
  an invite) and `me()`; info for create, join, leave,
  direct start, hide and unhide, room register/admit/leave, terms acceptance and reports; `MockInviteLedger.send` logs
  info under the target's `logCategory` [`lily/Features/Groups/Implementations/MockInviteCandidatePool.swift`:`MockInviteLedger.send`].
- Clock reads through the injected `now()` (once in `MockGroupRepository.init`, then per create, delete, direct start,
  join, invite, terms acceptance and report); `UUID()` for each mock report receipt id
  [`lily/Features/Groups/Implementations/MockModerationRepository.swift`:`MockModerationRepository.report`].
- No `Task.sleep`, disk or `UserDefaults` access anywhere in the directory.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Groups`, for
  example `RemoteGroupRepositoryTests`, `RemoteInviteRepositoryTests`, `RemoteMeRepositoryTests`,
  `RemoteModerationRepositoryTests`, `MockGroupRepositoryTests` (refusal cases in `MockGroupRepositoryRefusalTests.swift`),
  `MockGroupRepositoryOrderTests`, `MockInviteRepositoryTests`, `MockMeAndModerationRepositoryTests`).
