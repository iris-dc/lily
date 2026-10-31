# Events Services

Source: `lily/Features/Events/Services/`

## Overview

One service, `EventOpener`: the shared path that turns an event id into the detail screen, used by the inbox reminder
card and by a tapped reminder notification. It fetches the event through the injected `EventRepository`
([Interfaces](../Interfaces/EGM.md)) and hands it to `AppNavigation.openFromNotification`; a failure other than
cancellation is logged at warning and forwarded to `GroupErrorReporter`, which reaches the shared error popup. The
class carries no `nonisolated` marker and so runs on the main actor by the target's default.

## Interface

- `EventOpener` (`lily/Features/Events/Services/EventOpener.swift`): `final class`, not `Sendable`.
  - `init(events: any EventRepository, navigation: AppNavigation, reporter: GroupErrorReporter, logger: any Logging)`:
    stores the four dependencies and does nothing else.
  - `@discardableResult func open(eventID: String, from source: String) async -> Bool`: `true` once the event was
    fetched and pushed, `false` on any error, cancellation included. `source` appears only in the warning line.

## Invariants

- Ordering (`EventOpener.open`): `events.event(id:)` is awaited first; `navigation.openFromNotification(event)` runs
  only after a successful fetch, and then the method returns `true`.
- Cancellation is silent (`EventOpener.open`): `guard !AppError.isCancellation(error) else { return false }` runs
  before any logging or reporting (`AppError.isCancellation` covers `Task.isCancelled`, `CancellationError` and
  `URLError.cancelled`, `lily/Core/Errors/AppError.swift`).
- `open` never throws: failures surface only through the `Bool`, the logger and the reporter.
- Main-actor isolation: `AppNavigation` and `GroupErrorReporter` are called directly, with no actor hops.

## Side Effects

- Repository read: `events.event(id: eventID)` (`EventOpener.open`); with `RemoteEventRepository` this is
  `GET /api/events/{id}`.
- Navigation write: `navigation.openFromNotification(event)` (`lily/Core/Navigation/AppNavigation.swift`), which
  pushes onto the Chats stack when `AppConfig.FeatureFlags.chat` is on, otherwise onto Home.
- Logging: `logger.warning(.events, "Event <id> behind <source> is unavailable: <error>")` on a non-cancellation
  failure.
- Error reporting: `reporter.report(error)` (`lily/Features/Groups/Services/GroupErrorReporter.swift`) wraps the error
  into `AppError`, forwards it to `ErrorCenter.report` and invokes `onTermsRequired` for `.termsRequired`.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Events/EventOpenerTests.swift`).
