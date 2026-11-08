# Inbox Implementations

Source: `lily/Features/Inbox/Implementations/`

## Overview

The two concrete `InboxRepository` types and the fixture builder the mock uses. `RemoteInboxRepository` maps each
protocol method to one `APIRequest` under `/api/me/inbox` through `APIClient.send(_:failingWith:)`.
`MockInboxRepository` keeps the fixture items in memory (four; six with the deletion notices under
`-mock-deleted-user`), mirrors the backend's monotonic read marker and invite refusals, and delegates admission to the
group and tournament mocks; `MockInboxFixtures` builds those items from the
other features' fixtures, so previews, UI tests and `-mock-events` runs need no backend.

## Interface

- `final class RemoteInboxRepository: InboxRepository`
  `[lily/Features/Inbox/Implementations/RemoteInboxRepository.swift:RemoteInboxRepository]`: `init(client: any APIClient)`;
  `page(before:limit:)`, `markRead(itemID:)` (answers `InboxReadMarker.lastReadId`), `accept(itemID:)`,
  `decline(itemID:)` (answers `InviteDeclination.item`).
- `final class MockInboxRepository: InboxRepository`
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:MockInboxRepository]`:
  `init(groups: MockGroupRepository, tournaments: MockTournamentRepository, identity: any IdentityProvider, logger: any Logging, deletedUser: Bool = false, now: @escaping () -> Date = { .now })`;
  private `items: [InboxItem]`, `lastReadID: String?`; helpers `admittance(for:entering:)`, `invite(at:)`,
  `requireUser()`.
- `nonisolated enum MockInboxFixtures` `[lily/Features/Inbox/Implementations/MockInboxFixtures.swift:MockInboxFixtures]`:
  `tournamentInviteID`, `reminderID`, `matchReminderID`, `inviteID`, `eventCancelledID`, `ownershipID`
  (`itemID(index:)` 1 to 6), `inviterName`
  (`"Noor"`), `itemID(index:)` (prefix `01J8MOCKNB` plus a zero-padded 16-digit index), `make(now:) -> [InboxItem]`
  (oldest first: tournament invite, event reminder, match reminder, group invite) and `deletionNotices(now:)` (the
  cancelled "Friday 5-a-side" snapshot, no event behind it, and Sunday Padel Crew handed to the caller), built from
  `MockTournamentFixtures`, `MockEventFixtures` and `MockGroupFixtures`.

## Invariants

- Remote: `before` is sent only when non-nil, `limit` always; reads and the marker fall back to
  `AppError.inboxUnavailable`, accept and decline to `AppError.inviteActionFailed`
  `[lily/Features/Inbox/Implementations/RemoteInboxRepository.swift:RemoteInboxRepository]`.
- Mock: every method first requires `identity.currentUserID`, else throws `AppError.sessionExpired`
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:requireUser]`.
- Mock paging compares ids as strings (`id < before`) and answers `suffix(limit)`, so the ascending fixture order is
  kept; `hasMore` when more remain, `nextBefore = page.first?.id` only then, `lastReadId` echoes the marker
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:page]`.
- Mock marker is monotonic: `lastReadID = max(lastReadID ?? "", itemID)` and the result is returned; no existence
  check `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:markRead]`.
- An unknown id or an item without an invite payload throws `AppError.inviteNotPending`
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:invite(at:)]`.
- Accept: `.declined` or an `.unknown` status throws `inviteNotPending` (Laurel refuses a non-pending invite);
  `.accepted` replays the same shape without re-joining; `.pending`
  past `expiresAt` throws `AppError.inviteExpired`; otherwise admission runs before the item turns accepted, so a
  refused admission leaves it pending `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:accept]`.
- Decline: `.accepted` or an `.unknown` status throws `inviteNotPending`; `.declined` answers the same item; `.pending` is declined at
  `now()`; expiry is not checked `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:decline]`.
- Admission: a group invite calls `groups.admit(id:)` on every accept, replay included; a tournament invite calls
  `tournaments.join(id:teamName: nil)` only when entering and `!invite.isTeam`, and always answers
  `tournaments.invited(id)`; an item with neither payload throws `inviteNotPending`
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:admittance]`.
- Fixtures are built once from `now()` at init — `deletionNotices` appended only under `deletedUser` — and each
  pending tournament invite is registered with `tournaments.noteInvitee(of:)`
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:init]`.
- Fixture ids order lexically as created; ages are 2 days, 10 min, 5 min, 60 s and (the notices) 40 s and 30 s
  before `now`; a builder answering
  `nil` (a missing group, event or match fixture) is dropped; invites expire after `AppConfig.Inbox.mockInviteExpiry`
  (7 days) and the event reminder starts after `AppConfig.Inbox.mockReminderLead` (1 hour)
  `[lily/Features/Inbox/Implementations/MockInboxFixtures.swift:make]`, `[lily/Config/AppConfig+Inbox.swift:AppConfig.Inbox]`.
- Both classes are main-actor isolated by the target's default; the mock's mutable state has no other protection
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:MockInboxRepository]`.

## Side Effects

- `GET /api/me/inbox?before=<id>&limit=<n>` decoding `InboxPage`
  `[lily/Features/Inbox/Implementations/RemoteInboxRepository.swift:page]`,
  `[lily/Config/AppConfig+Inbox.swift:AppConfig.API.Paths.inbox]`.
- `PUT /api/me/inbox/read` with body `InboxReadPayload { itemId }` decoding `InboxReadMarker`
  `[lily/Features/Inbox/Implementations/RemoteInboxRepository.swift:markRead]`,
  `[lily/Config/AppConfig+Inbox.swift:AppConfig.API.Paths.inboxRead]`.
- `POST /api/me/inbox/{itemId}/accept` decoding `InviteAcceptance` and `POST /api/me/inbox/{itemId}/decline`
  decoding `InviteDeclination`, no body
  `[lily/Features/Inbox/Implementations/RemoteInboxRepository.swift:accept]`,
  `[lily/Features/Inbox/Implementations/RemoteInboxRepository.swift:decline]`,
  `[lily/Config/AppConfig+Inbox.swift:AppConfig.API.Paths.inboxAccept(id:)]`,
  `[lily/Config/AppConfig+Inbox.swift:AppConfig.API.Paths.inboxDecline(id:)]`.
- Mock logging under `.inbox`: debug on a page served, info on a decline and on an accept into a group or a
  tournament `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:page]`,
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:decline]`,
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:admittance]`.
- Mock mutates the sibling mocks: `groups.admit(id:)`, `tournaments.join(id:teamName:)`, `tournaments.invited(_:)`,
  `tournaments.noteInvitee(of:)` `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:admittance]`,
  `[lily/Features/Inbox/Implementations/MockInboxRepository.swift:init]`.
- In-memory `items` and `lastReadID` only; no disk, UserDefaults, timers, spawned tasks or delays in either
  implementation.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Inbox/MockInboxRepositoryTests.swift`, `RemoteInboxRepositoryTests.swift`).
