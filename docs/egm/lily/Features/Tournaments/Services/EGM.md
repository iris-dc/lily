# Tournaments: Services

Source: `lily/Features/Tournaments/Services/`

## Overview

One service. `TournamentOpener` turns a tournament id (and optionally a match id) carried by a push notification into
the tournament's detail screen: it fetches the detail through `TournamentRepository`
([`../Interfaces/EGM.md`](../Interfaces/EGM.md)), builds a `TournamentDestination`
(`lily/Features/Tournaments/Models/Tournament.swift`) and pushes it through `AppNavigation.openFromNotification`
(`lily/Core/Navigation/AppNavigation.swift`). It is built in `lily/App/AppDependencies+Push.swift` and called from
`lily/Core/Push/PushCoordinator.swift` with the source `"a notification"`; the inbox's reminder card carries the name
itself and needs no fetch. A tournament that is gone or unreachable reaches the shared popup; cancellation stays quiet.

## Interface

- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener]`: `final class TournamentOpener`, no
  isolation annotation, so main-actor isolated under the app target's default. Dependencies, all injected:

```swift
init(tournaments: any TournamentRepository,
     navigation: AppNavigation,
     reporter: GroupErrorReporter,   // lily/Features/Groups/Services/GroupErrorReporter.swift
     logger: any Logging)
```

- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener.open(tournamentID:matchID:from:)]`:
  `@discardableResult func open(tournamentID: String, matchID: String?, from source: String) async -> Bool`. Awaits
  `tournaments.tournament(id:)`, builds `TournamentDestination(id:name:matchID:preview:)` with `detail.tournament.name`
  and the whole `detail.tournament` as `preview`, calls `navigation.openFromNotification(destination)` and returns
  `true`. Any thrown error returns `false`.

## Invariants

- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener.open(tournamentID:matchID:from:)]`:
  fetch before navigate. The destination is built from the fetched detail, so a failed fetch pushes nothing and a
  pushed destination always carries a `preview` the detail screen can draw before its own load.
- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener.open(tournamentID:matchID:from:)]`:
  `matchID` is passed through untouched; the detail screen decides what to do with it (a named match opens its sheet).
- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener.open(tournamentID:matchID:from:)]`: a
  cancellation (`AppError.isCancellation(error)`, `lily/Core/Errors/AppError.swift`: `Task.isCancelled`, a
  `CancellationError`, or `URLError.cancelled`) returns `false` with no log line and no popup.
- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener.open(tournamentID:matchID:from:)]`:
  every other failure is both logged and reported, in that order; the log line names the tournament id and `source`,
  never the user. `source` is used only in that log line.
- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener]`: the class holds no state beyond its
  four dependencies; repeated `open` calls are independent and the method is safe to call again after a failure.

## Side Effects

- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener.open(tournamentID:matchID:from:)]`:
  network: one `TournamentRepository.tournament(id:)` call per `open`.
- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener.open(tournamentID:matchID:from:)]`:
  navigation: `AppNavigation.openFromNotification(_:)` (`lily/Core/Navigation/AppNavigation.swift`) selects the Chats
  tab and appends the destination to `chatPath` when `AppConfig.FeatureFlags.chat` is on, otherwise selects Home and
  appends to `homePath`.
- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener.open(tournamentID:matchID:from:)]`:
  logging: `logger.warning(.tournaments, "Tournament <id> behind <source> is unavailable: <error>")` on a
  non-cancellation failure (`LogCategory.tournaments`, `lily/Core/Logging/Interfaces/Logging.swift`).
- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener.open(tournamentID:matchID:from:)]`:
  error popup: `reporter.report(error)` wraps the error as `AppError`, hands it to `ErrorCenter`, and runs the
  terms-required callback when the error is `.termsRequired`
  (`lily/Features/Groups/Services/GroupErrorReporter.swift`).
- `[lily/Features/Tournaments/Services/TournamentOpener.swift:TournamentOpener]`: no disk, UserDefaults, timers or
  spawned tasks.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Tournaments`).
