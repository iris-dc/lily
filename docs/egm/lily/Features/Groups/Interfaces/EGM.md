# Groups Interfaces

Source: `lily/Features/Groups/Interfaces/`

## Overview

The protocol boundary of the Groups feature. Six files, one protocol each, no concrete types and no state: four
repository protocols (groups, direct invites, the caller's own account, moderation), one recorder the chat layer
calls into, and one view-model protocol that lets group create and edit share a single form. Every behavioural
guarantee here is a doc-comment contract that a conformer must honour; the conformers are the `Remote*` and `Mock*`
classes in [Implementations](../Implementations/EGM.md), the stores in [State](../State/EGM.md) and the view models
in [ViewModels](../ViewModels/EGM.md). Failures surface as `AppError`.

## Interface

- `GroupRepository` reads: `groups(in: GroupScope, cursor: String?, near: Coordinate?) async throws -> Page<SportGroup>`,
  `group(id:) -> SportGroup`, `members(id:) -> [GroupMember]`, `bans(id:) -> [GroupMember]`
  [`lily/Features/Groups/Interfaces/GroupRepository.swift`:`GroupRepository.groups`].
- `GroupRepository` writes: `create(_ draft: GroupDraft) -> SportGroup`, `update(id:_ draft:) -> SportGroup`,
  `delete(id:) -> SportGroup`, `join(id:) -> SportGroup`, `leave(id:) -> SportGroup`, `remove(id:userID:) -> SportGroup`,
  `setRole(id:userID:_ role: MemberRole) -> GroupMember`, `unban(id:userID:)` (Void); all `async throws`
  [`lily/Features/Groups/Interfaces/GroupRepository.swift`:`GroupRepository.create`].
- `InviteRepository`: `candidates(groupID:) async throws -> [InviteCandidate]`,
  `invite(groupID:userID:) async throws -> SentInvite`
  [`lily/Features/Groups/Interfaces/InviteRepository.swift`:`InviteRepository`].
- `MeRepository`: `me() async throws -> Account`, `acceptTerms(version: Int) async throws -> TermsAcceptance`
  [`lily/Features/Groups/Interfaces/MeRepository.swift`:`MeRepository`].
- `ModerationRepository`: `report(_: ReportPayload) async throws -> ReportReceipt`, `blocks() -> Set<String>`,
  `block(userID:) -> Set<String>` (no unblock: the app has no screen for one; Laurel's `DELETE /api/blocks/{userId}` has no caller)
  [`lily/Features/Groups/Interfaces/ModerationRepository.swift`:`ModerationRepository`].
- `RoomActivityRecorder: AnyObject`: one synchronous, non-throwing requirement
  `noteMessage(_ message: ChatMessage, in groupID: String)`
  [`lily/Features/Groups/Interfaces/RoomActivityRecorder.swift`:`RoomActivityRecorder`].
- `GroupDraftEditing: DraftSubmitting where Issue == GroupDraft.Issue`, adding `var draft: GroupDraft { get set }`;
  through `DraftSubmitting` (`lily/Core/UI/Interfaces/DraftSubmitting.swift`) it is class-bound and `Observable`
  and carries `issues: [Issue]`, `isSubmitting`, `canSubmit`, `isDone`, `prepare() async`, `submit() async`
  [`lily/Features/Groups/Interfaces/GroupDraftEditing.swift`:`GroupDraftEditing`].

## Invariants

- Every repository requirement is `async throws`; `GroupRepository` and `InviteRepository` document that failures
  arrive as `AppError`, and every `GroupRepository` write answers the group (or member) as the server now sees it
  [`lily/Features/Groups/Interfaces/GroupRepository.swift`:`GroupRepository`].
- `groups(in:cursor:near:)`: `.mine` answers every group the caller is in, most recently active first, in one page;
  `.discover` pages public groups with `cursor` taken from the previous page's `nextCursor`; with a position and no
  query, Discover answers ranked nearby groups in one page without a cursor
  [`lily/Features/Groups/Interfaces/GroupRepository.swift`:`GroupRepository.groups`].
- `group(id:)` throws `AppError.groupNotFound` for a deleted group and for a private group the caller is not in
  [`lily/Features/Groups/Interfaces/GroupRepository.swift`:`GroupRepository.group`].
- `create` is idempotent on `GroupDraft.clientId` (the same id answers the same group) and makes the caller owner and
  first member; `delete` is a soft delete answering `deletedAt`, owners and operators only; `join` is for public groups
  only (a private group is entered by accepting an invite through `InboxRepository.accept`)
  [`lily/Features/Groups/Interfaces/GroupRepository.swift`:`GroupRepository.create`].
- Roles: owners may set `.admin` and `.member`; `.banned` may be set by admins on members and by owners on members
  and admins. `members` is for members only, ordered owner, admins, then join time; `bans` is for admins only and
  answers banned markers whose `joinedAt` is the ban time
  [`lily/Features/Groups/Interfaces/GroupRepository.swift`:`GroupRepository.setRole`].
- `candidates` are sorted by name, never include the group's members or banned users, and `isInvited` marks a
  pending invite; `invite` is idempotent for a pending invitee (a repeat answers the existing invite)
  [`lily/Features/Groups/Interfaces/InviteRepository.swift`:`InviteRepository.candidates`].
- `acceptTerms(version:)` must be called with the current `Account.termsVersion`
  [`lily/Features/Groups/Interfaces/MeRepository.swift`:`MeRepository.acceptTerms`].
- Block routes answer the caller's whole block list, so callers replace their copy rather than merge
  [`lily/Features/Groups/Interfaces/ModerationRepository.swift`:`ModerationRepository`].
- `RoomActivityRecorder` is class-bound and must be told of every message that lands in a room, the caller's own
  included [`lily/Features/Groups/Interfaces/RoomActivityRecorder.swift`:`RoomActivityRecorder`].
- `GroupDraftEditing.prepare()` belongs to the parent: a create proposes the device position as the spot, an edit
  proposes nothing because the draft already holds the group's place
  [`lily/Features/Groups/Interfaces/GroupDraftEditing.swift`:`GroupDraftEditing`].

## Side Effects

- None performed by these files: they are protocol declarations only.
- Contracts conformers must carry out: create, update, soft-delete, join, leave, remove, set-role and unban on the
  backend [`lily/Features/Groups/Interfaces/GroupRepository.swift`:`GroupRepository`]; send a direct invite
  [`lily/Features/Groups/Interfaces/InviteRepository.swift`:`InviteRepository.invite`]; record terms acceptance
  [`lily/Features/Groups/Interfaces/MeRepository.swift`:`MeRepository.acceptTerms`]; file a report and mutate the
  block list [`lily/Features/Groups/Interfaces/ModerationRepository.swift`:`ModerationRepository`]; record room
  activity so the Chats list reorders by latest message without a reload
  [`lily/Features/Groups/Interfaces/RoomActivityRecorder.swift`:`RoomActivityRecorder.noteMessage`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Groups`, for
  example `RemoteGroupRepositoryTests`, `MockGroupRepositoryTests` (its refusal cases live in
  `MockGroupRepositoryRefusalTests.swift`), `MockInviteRepositoryTests`).
