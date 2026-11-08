# Events Services

Source: `lily/Features/Events/Services/`

## Overview

Two services. `EventOpener`: the shared path that turns an event id into the detail screen, used by the inbox reminder
card and by a tapped reminder notification. It fetches the event through the injected `EventRepository`
([Interfaces](../Interfaces/EGM.md)) and hands it to `AppNavigation.openFromNotification`; a failure other than
cancellation is logged at warning and forwarded to the shared `ErrorCenter`, the error popup's funnel. The
class carries no `nonisolated` marker and so runs on the main actor by the target's default.

## Interface

- `EventOpener` (`lily/Features/Events/Services/EventOpener.swift`): `final class`, not `Sendable`.
- `PlaceResolver` (`lily/Features/Events/Services/PlaceResolver.swift`): `struct` over `geocoder: any GeocodingService`
  and `logger`; `resolve(_ draft: EventDraft, near position: Coordinate? = nil) async throws -> EventDraft` settles the
  place before the send. Every forward lookup is biased to the draft's spot, else `position` (the user's, or an edited
  game's stored spot), so a venue name resolves nearby. A missing spot is geocoded from the trimmed name
  (`AppError.placeNotFound` when nothing answers; the geocoder's `AppError.network` when it could not be asked, logged
  at warning "reporting a network error" and rethrown, never "Couldn't find this place"; the draft kept for a
  correction either way); a missing name comes from the geocoder when it fits the backend's cap and falls back to
  `AppBranding.Events.Create.coordinateText` otherwise, so the payload never goes out blank; a spot the user never
  picked (`!spotPickedOnMap`, the GPS proposal) is overridden by a typed name the geocoder knows, unless the name is
  the one already resolved (`suggestedName`), and a failed override (no match, or the geocoder could not be asked)
  keeps the proposal with a warning ("the proposed spot stands") rather than blocking a venue the geocoder has never
  heard of; a successful override logs at info whether it landed "within" or "beyond" the search region
  (`AppConfig.Events.placeSearchRegionMeters / 2` from the proposal), the one sign of a far-off namesake. A picked
  spot passes untouched. A cancellation passes through unlogged. Logs outcomes under `.location`, never the text.
  - `init(events: any EventRepository, navigation: AppNavigation, errorCenter: ErrorCenter, logger: any Logging)`:
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
- Main-actor isolation: `AppNavigation` and `ErrorCenter` are called directly, with no actor hops.

## Side Effects

- Repository read: `events.event(id: eventID)` (`EventOpener.open`); with `RemoteEventRepository` this is
  `GET /api/events/{id}`.
- Navigation write: `navigation.openFromNotification(event)` (`lily/Core/Navigation/AppNavigation.swift`), which
  pushes onto the Chats stack when `AppConfig.FeatureFlags.chat` is on, otherwise onto Home.
- Logging: `logger.warning(.events, "Event <id> behind <source> is unavailable: <error>")` on a non-cancellation
  failure.
- Error reporting: `errorCenter.report(error)` wraps the error into `AppError` and shows the shared popup.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (`lilyTests/Events/EventOpenerTests.swift`,
  `lilyTests/Events/PlaceResolverTests.swift`; the view models' use in `CreateEventViewModelTests`,
  `CreateEventPlaceTests` and `EditEventPlaceTests`).
