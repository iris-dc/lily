# People Implementations

Source: `lily/Features/People/Implementations/`

## Overview

The two `UserRepository` types. `RemoteUserRepository` sends one `APIRequest` per method to Laurel through
`APIClient.send(_:failingWith:)`. `MockUserRepository` serves profiles from the other mocks: a person is whoever any
roster of the group mock names, their bio a `MockUserFixtures` line (the caller's own is the profile mock's), the groups
in common the caller's communities whose roster names them, the games together the caller's joined games (event mock)
whose participants name them, the tournaments together the tournament mock's rooms both are in; conversations are the
group mock's direct groups. So previews, UI tests and `-mock-events` runs need no backend.

## Interface

- `final class RemoteUserRepository: UserRepository`
  `[lily/Features/People/Implementations/RemoteUserRepository.swift:RemoteUserRepository]`: `init(client: any APIClient)`;
  `profile(userID:)`, `startConversation(with:)`.
- `final class MockUserRepository: UserRepository`
  `[lily/Features/People/Implementations/MockUserRepository.swift:MockUserRepository]`:
  `init(groups: MockGroupRepository, events: MockEventRepository, tournaments: MockTournamentRepository,
  profiles: MockProfileRepository, identity: any IdentityProvider, logger: any Logging)`; `profile(userID:)`,
  `startConversation(with:)`; private `bio(of:isSelf:)`, `summaries(_:)`, `sharedEvents(with:isSelf:)`,
  `sharedTournaments(with:isSelf:)`, `involves(_:_:)`, `latestFirst(_:by:)`.
- `nonisolated enum MockUserFixtures` `[lily/Features/People/Implementations/MockUserFixtures.swift:MockUserFixtures]`:
  `bio(of userID: String) -> String?`, the fixture bios by name (Marta, Jonas, Dev; Marta's is Laurel's contract
  sample's line), nothing for anyone else.

## Invariants

- Remote: a profile failure falls back to `AppError.profileUnavailable`, a conversation failure to
  `AppError.conversationFailed` `[lily/Features/People/Implementations/RemoteUserRepository.swift:profile]`,
  `[lily/Features/People/Implementations/RemoteUserRepository.swift:startConversation]`.
- Mock: both methods require `identity.currentUserID`, else throw `AppError.sessionExpired`
  `[lily/Features/People/Implementations/MockUserRepository.swift:profile]`,
  `[lily/Features/People/Implementations/MockUserRepository.swift:startConversation]`.
- Mock profile: the caller's own id answers their own communities, games and tournaments under
  `AppBranding.Groups.Create.mockOwnerName`, with the bio the profile mock holds, as the backend does; an id no roster
  names throws `AppError.userNotFound`; the shared groups are the caller's `isCommunity` groups (from
  `groups.groups(in: .mine, cursor: nil, near: nil)`) whose roster holds the user with a role other than `.banned`, so
  a direct conversation is never a group in common `[lily/Features/People/Implementations/MockUserRepository.swift:profile]`.
- Mock history: the games together are the caller's `.joined` events whose `participants(eventId:)` name the user (the
  host included); the tournaments together are the tournament mock's `details` whose room the caller is in
  (`isInRoom`) and which the user organises or has an entry in, `resolved` and with `.cancelled` dropped; both lists are
  sorted latest start first and cut to `AppConfig.People.maxSharedHistory`, as Laurel answers them
  `[lily/Features/People/Implementations/MockUserRepository.swift:sharedEvents]`,
  `[lily/Features/People/Implementations/MockUserRepository.swift:sharedTournaments]`,
  `[lily/Features/People/Implementations/MockUserRepository.swift:latestFirst]`.
- Mock summaries are sorted by name, as the backend answers them
  `[lily/Features/People/Implementations/MockUserRepository.swift:summaries]`.
- Mock conversation: messaging yourself throws `AppError.conversationFailed`; an unknown user throws
  `AppError.userNotFound`; otherwise `groups.startDirect(with:name:)` answers the direct group
  `[lily/Features/People/Implementations/MockUserRepository.swift:startConversation]`.
- Both classes are main-actor isolated by the target's default.

## Side Effects

- `GET /api/users/{id}` decoding `UserProfile` `[lily/Features/People/Implementations/RemoteUserRepository.swift:profile]`,
  `[lily/Config/AppConfig+People.swift:AppConfig.API.Paths.user(id:)]`.
- `POST /api/conversations` with body `StartConversationPayload { userId }` decoding `SportGroup`
  `[lily/Features/People/Implementations/RemoteUserRepository.swift:startConversation]`,
  `[lily/Config/AppConfig+People.swift:AppConfig.API.Paths.conversations]`.
- Mock: reads `groups.groups(in:cursor:near:)`, `groups.displayName(ofUser:)`, `groups.roster(of:)`,
  `events.events(in: .joined, near: nil)`, `events.participants(eventId:)`, `tournaments.details`, `isInRoom`,
  `resolved` and `profiles.profile()` (the caller's own, which creates the mock profile if absent), and mutates the
  group mock through `groups.startDirect(with:name:)`; a debug log under `.groups` for every profile served, with the
  three counts
  `[lily/Features/People/Implementations/MockUserRepository.swift:profile]`,
  `[lily/Features/People/Implementations/MockUserRepository.swift:startConversation]`.
- No disk, UserDefaults, timers or spawned tasks.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/People/MockUserRepositoryTests.swift`, `RemoteUserRepositoryTests.swift`; the
  wiring through `lilyTests/App/AppDependenciesPeopleTests.swift`).
