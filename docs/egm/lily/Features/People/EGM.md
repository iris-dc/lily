# People

Source: `lily/Features/People/`

## Overview

The people feature: every person named in the app opens a profile (initials, name, a Message button and the groups the
caller shares with them), and Message opens a direct conversation, a two-member private group of kind `direct` that the
backend derives once per pair. Data flows from `UserRepository` (`GET /api/users/{id}`, `POST /api/conversations`)
through `UserProfileViewModel` to `UserProfileView`; a new conversation goes into `MyGroupsStore` and opens through
`AppNavigation`. No source files live at this level; the five subdirectories below hold them.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `UserRepository` with `profile(userID:)` (throws
  `AppError.userNotFound`) and `startConversation(with:)` (idempotent per pair).
- Models: [./Models/EGM.md](./Models/EGM.md) - `UserProfile`, `GroupSummary` (with `caption` and `ref: EventGroupRef`),
  `StartConversationPayload`, `UserProfileDestination` (with `GroupDetailContext`).
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `RemoteUserRepository` (`GET /api/users/{id}`,
  `POST /api/conversations`) and `MockUserRepository` serving profiles from the group mock's rosters and conversations
  as its direct groups.
- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `UserProfileViewModel`: `State` (loading, loaded, failed),
  `canMessage` (signed in, not yourself, standalone context), single-flight `message()` through a `WriteGate`.
- Views: [./Views/EGM.md](./Views/EGM.md) - `PersonRow`, `SharedGroupRow`, `UserProfileView` with the Message
  `BusyButton` and the shared-groups list.
