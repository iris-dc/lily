# People Implementations

Source: `lily/Features/People/Implementations/`

## Overview

The two `UserRepository` types. `RemoteUserRepository` sends one `APIRequest` per method to Laurel through
`APIClient.send(_:failingWith:)`. `MockUserRepository` serves profiles from the group mock's rosters (a person is
whoever any roster names; the groups in common are the caller's communities whose roster names them) and conversations
as the group mock's direct groups, so previews, UI tests and `-mock-events` runs need no backend.

## Interface

- `final class RemoteUserRepository: UserRepository`
  `[lily/Features/People/Implementations/RemoteUserRepository.swift:RemoteUserRepository]`: `init(client: any APIClient)`;
  `profile(userID:)`, `startConversation(with:)`.
- `final class MockUserRepository: UserRepository`
  `[lily/Features/People/Implementations/MockUserRepository.swift:MockUserRepository]`:
  `init(groups: MockGroupRepository, identity: any IdentityProvider, logger: any Logging)`; `profile(userID:)`,
  `startConversation(with:)`; private `summaries(_:)`.

## Invariants

- Remote: a profile failure falls back to `AppError.profileUnavailable`, a conversation failure to
  `AppError.conversationFailed` `[lily/Features/People/Implementations/RemoteUserRepository.swift:profile]`,
  `[lily/Features/People/Implementations/RemoteUserRepository.swift:startConversation]`.
- Mock: both methods require `identity.currentUserID`, else throw `AppError.sessionExpired`
  `[lily/Features/People/Implementations/MockUserRepository.swift:profile]`,
  `[lily/Features/People/Implementations/MockUserRepository.swift:startConversation]`.
- Mock profile: the caller's own id answers their own communities under `AppBranding.Groups.Create.mockOwnerName`, as
  the backend does; an id no roster names throws `AppError.userNotFound`; the shared groups are the caller's
  `isCommunity` groups (from `groups.groups(in: .mine, cursor: nil, near: nil)`) whose roster holds the user with a
  role other than `.banned`, so a direct conversation is never a group in common
  `[lily/Features/People/Implementations/MockUserRepository.swift:profile]`.
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
- Mock: reads `groups.groups(in:cursor:near:)`, `groups.displayName(ofUser:)` and `groups.roster(of:)`, and mutates
  the group mock through `groups.startDirect(with:name:)`; a debug log under `.groups` when another user's profile is served (the caller's own answers without one)
  `[lily/Features/People/Implementations/MockUserRepository.swift:profile]`,
  `[lily/Features/People/Implementations/MockUserRepository.swift:startConversation]`.
- No disk, UserDefaults, timers or spawned tasks.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/People/MockUserRepositoryTests.swift`, `RemoteUserRepositoryTests.swift`).
