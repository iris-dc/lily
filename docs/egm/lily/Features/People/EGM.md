# People

Source: `lily/Features/People/`

## Overview

The people feature: every person named in the app opens a profile (initials, name, a Message button, what they wrote
about themselves, and what the caller shares with them: groups, games and tournaments), and Message opens a direct
conversation, a two-member private group of kind `direct` that the
backend derives once per pair. Data flows from `UserRepository` (`GET /api/users/{id}`, `POST /api/conversations`)
through `UserProfileViewModel` to `UserProfileView`; a new conversation goes into `MyGroupsStore` and its chat is pushed
on the stack the profile is on, so Back returns to the profile. No source files live at this level; the five subdirectories below hold them.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `UserRepository` with `profile(userID:)` (throws
  `AppError.userNotFound`) and `startConversation(with:)` (idempotent per pair).
- Models: [./Models/EGM.md](./Models/EGM.md) - `UserProfile` (name, `bio?`, the three shared lists), `GroupSummary`
  (with `caption` and `ref: EventGroupRef`), `EventSummary` (with `caption`), `TournamentSummary` (with `caption` and
  `destination: TournamentDestination`), `StartConversationPayload`, `UserProfileDestination` (with `GroupDetailContext`),
  and `Tombstone` (the deletion contract's flag mapped once to the localized "Deleted user" and its fixed mark).
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `RemoteUserRepository` (`GET /api/users/{id}`,
  `POST /api/conversations`) and `MockUserRepository` serving profiles from the group mock's rosters (the shared
  history from the event and tournament mocks, the bios from `MockUserFixtures`) and conversations as its direct groups.
- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `UserProfileViewModel`: `State` (loading, loaded, failed),
  `canMessage` (chat on, signed in, not yourself, standalone context), single-flight `message()` through a `WriteGate`
  whose success the view pushes as the chat on the profile's own stack (`openedConversation`).
- Views: [./Views/EGM.md](./Views/EGM.md) - `PersonRow`, `SharedGroupRow`, `SharedEventRow`, `SharedTournamentRow`,
  `UserProfileView` with the Message `BusyButton`, the bio and the three shared sections.
