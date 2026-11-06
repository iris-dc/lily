# lily/Features/Events

Source: `lily/Features/Events/`

## Overview

The Events feature of iskra: finding sport events near the user, joining and leaving them, creating and editing
one's own. The directory holds no source files of its own; its six folders follow the project's layer split.
`Interfaces` declares the protocols (`EventRepository`, `EventFilterStore`, `EventDraftEditing`); `Models` the
`nonisolated` value types (`SportEvent`, `EventDraft`, `EventFilter`, the wire enums `EventType` and `SkillLevel`,
the decision enums); `Implementations` the remote and mock repositories and the filter stores; `Services` the
`EventOpener`; `ViewModels` the four `@Observable` owners of screen state; `Views` the SwiftUI screens and reusable
cards. Data flows Views → ViewModels → Interfaces → Implementations → Laurel (`/api/events...`), with `Models` shared
by every layer. Contracts live out of tree under `docs/egm/` because `lily/` may hold only Swift sources, catalogs and the privacy manifest.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `EventRepository` (seven `async throws` calls answering
  the server-side `SportEvent`), `EventFilterStore` (synchronous `load`/`save`/`clear`) and `EventDraftEditing`
  (the `DraftSubmitting` refinement the shared form is generic over). Protocols only, no side effects.
- Models: [./Models/EGM.md](./Models/EGM.md) - the wire-shaped `SportEvent` and payloads with hand-written tolerant
  decoding, `WireNamedKind` enums with `unknown(String)`, `EventDraft` validation against `AppConfig.Events` limits,
  the on-device `EventFilter` and its persisted form, and the pure decision types (`EventListScreenState`,
  `Participation`, `CreateIntentPolicy`, `PickerSettlePolicy`, `MapFraming`, `EventScope`).
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `RemoteEventRepository` (GET/POST/PUT/
  DELETE under `/api/events` and `/api/groups/{id}/events`, position only on Explore), `MockEventRepository` with
  Berlin fixtures and Laurel's refusal order, `UserDefaultsEventFilterStore` under `lily.events.filter`,
  `NoOpEventFilterStore`.
- Services: [./Services/EGM.md](./Services/EGM.md) - `EventOpener`, which fetches an event by id and pushes it
  through `AppNavigation.openFromNotification`, silent on cancellation, otherwise logging and reporting.
- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `EventListViewModel` (snapshot-first lists per
  `EventScope`, freshness and change-tracker reloads, position head start, `keep(_:for:)` under the right caller),
  `EventDetailViewModel` (join/leave through `LostRace.attemptTwice`, refetch on an unknown outcome),
  `CreateEventViewModel` (`CreateFlow` keyed on `clientId`) and `EditEventViewModel` (`WriteGate`).
- Views: [./Views/EGM.md](./Views/EGM.md) - the Explore screen and its states, the detail with its participation
  control, the generic `EventDraftForm` and sheets, the filter sheet, the events map and location picker, and the
  cards and rows reused by Groups and Tournaments.
