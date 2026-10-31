# Tournaments

Source: `lily/Features/Tournaments/`

## Overview

The Tournaments feature of the iskra app (code name lily): organiser-run competitions for one event type in a single
elimination or round robin format, with entries (players alone, or teams a captain names and teammates join), a
chat room of their own, and once started a bracket or standings whose results the players report and confirm while
the organiser records, decides disputes, gives walkovers and schedules matches. The folder holds no source files of
its own; its six subdirectories follow the app's layering: protocols in `Interfaces`, pure value types in `Models`,
concrete repositories and mocks in `Implementations`, one navigation service in `Services`, observable view models in
`ViewModels` and SwiftUI views in `Views`. Composition happens outside this folder in `lily/App/AppDependencies`
(+Tournaments and +Push extension files), the only place that knows the concrete types. The feature flag
`AppConfig.FeatureFlags.tournaments` is checked by the callers in the Shell, Groups, Events and Landing features
(`lily/Features/Shell/Views/ExploreTab.swift`, `HomeView.swift`, `HomeOverview.swift`,
`lily/Features/Shell/Services/ShellLists.swift`, `lily/Features/Groups/Views/GroupDetailView.swift`,
`GroupDetailMenu.swift`, `lily/Features/Groups/Models/GroupDetailSection.swift`,
`lily/Features/Events/Views/CreateMenuButton.swift`, `lily/Features/Landing/Models/IntroSlide.swift`,
`lily/App/ShellCommands.swift`), never inside these files (the one flag read here is `TournamentDetailViewModel`
reading `AppConfig.FeatureFlags.chat`). Unit tests live under `lilyTests/Tournaments` (42 suite files); the dated engineering notes are in
`docs/notes/tournaments.md`.

## Subdirectories & Boundaries

- Interfaces: [`./Interfaces/EGM.md`](./Interfaces/EGM.md) - `TournamentRepository`, the fifteen `async throws`
  reads and writes every caller depends on (lists by scope, detail, create and update, entries and teams, start,
  match result, confirm, dispute, walkover, schedule, cancel), and `TournamentDraftEditing`, the sheet contract
  refining `DraftSubmitting` for the create and edit form. Protocols only; the rules live as doc comments.
- Models: [`./Models/EGM.md`](./Models/EGM.md) - the `nonisolated`, `Sendable` value types: the wire records
  (`Tournament`, `TournamentDetail`, `TournamentEntry`, `TournamentMatch`, `MatchSchedule`, `TournamentStanding`,
  `TournamentChange`) with synthesized Codable, the status enums, the `Encodable` payloads, `TournamentDraft` with its
  validation against `AppConfig.Tournaments`, the decision types (`TournamentRole`, `TournamentParticipation`,
  `TournamentPermissions`, `MatchActions`, `MatchWrite`), `RoundRobinStandings`, `BracketLayout` and the
  `TournamentSchedule` pairing generator. No I/O.
- Implementations: [`./Implementations/EGM.md`](./Implementations/EGM.md) - `RemoteTournamentRepository` and
  `RemoteTournamentInviteRepository` over `APIClient` on the `/api/tournaments` routes, and the in-memory
  `MockTournamentRepository`, `MockTournamentInviteRepository` and `MockTournamentFixtures` (Kickers Cup, Tuesday
  Table Tennis, Padel Open) that mirror the backend's refusals and keep the tournament rooms in `MockGroupRepository`
  in step. Sends once; retries belong to the view models.
- Services: [`./Services/EGM.md`](./Services/EGM.md) - `TournamentOpener`, which fetches a tournament named by a push
  notification and pushes its `TournamentDestination` (with an optional match) through
  `AppNavigation.openFromNotification`, logging and reporting a failure, staying quiet on cancellation.
- ViewModels: [`./ViewModels/EGM.md`](./ViewModels/EGM.md) - `TournamentListViewModel` (snapshots, freshness,
  change tracking, position head start), `TournamentDetailViewModel` with its entries and matches extensions
  (preview, permissions, refetch after entry writes, read-back after an unknown match outcome through the view model's own `readBack`, every write framed by `WriteGate`),
  and the `CreateTournamentViewModel` and `EditTournamentViewModel` draft sheets (`CreateFlow`, `WriteGate`). Every
  dependency is a protocol or a shared store.
- Views: [`./Views/EGM.md`](./Views/EGM.md) - the carousel, Discover, group segment and cards; the detail screen with
  header, facts, entries, bracket or standings, matches, participation control and menu; the match, schedule and
  team-name sheets; and the generic `TournamentDraftForm` behind the create and edit sheets. Permissions and
  participation gate every control; sheets mount their own `.errorPopup`.
