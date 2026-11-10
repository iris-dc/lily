# Events Interfaces

Source: `lily/Features/Events/Interfaces/`

## Overview

The three protocols that bound the Events feature. `EventRepository` is the data boundary the view models call for
listing, reading, joining, leaving, creating and updating events; `EventFilterStore` is the persistence boundary for
Explore's filter; `EventDraftEditing` is the view-model contract the shared create/edit form (`EventDraftForm`) is
generic over. Nothing concrete lives here: the conformers are in [Implementations](../Implementations/EGM.md) and
[ViewModels](../ViewModels/EGM.md). None of the three carries a `nonisolated` marker, so each inherits the app
target's default `@MainActor` isolation.

## Interface

- `EventRepository` (`lily/Features/Events/Interfaces/EventRepository.swift`): every requirement is `async throws`.
  - `events(in scope: EventScope, near position: Coordinate?) -> [SportEvent]`: the position is documented as sent
    rounded to about a kilometre and only for `.upcoming`; `nil` keeps the backend's default order.
  - `event(id: String) -> SportEvent`: documented to throw `AppError.eventNotFound` when the event is gone.
  - `participants(eventId: String) -> [EventParticipant]`: host first, then by join time; for signed-in callers.
  - `join(eventId: String) -> SportEvent` and `leave(eventId: String) -> SportEvent`: answer the event as the server
    now sees it.
  - `create(_ draft: EventDraft) -> SportEvent`: the caller becomes host and first participant; documented idempotent
    on `EventDraft.clientId`.
  - `update(id: String, _ draft: EventDraft) -> SportEvent`: replaces every editable field of the caller's own event.
- `EventFilterStore` (`lily/Features/Events/Interfaces/EventFilterStore.swift`): synchronous, non-throwing
  `load() -> EventFilter?`, `save(_ filter: EventFilter)`, `clear()`.
- `EventDraftEditing` (`lily/Features/Events/Interfaces/EventDraftEditing.swift`):
  `protocol EventDraftEditing: DraftSubmitting where Issue == EventDraft.Issue`. Requirements:
  `draft: EventDraft { get set }`, `earliestStart: Date`, `capacityRange: ClosedRange<Int>`,
  `lockedGroup: EventGroupRef?`, `showsGroupRow: Bool`, `eligibleGroups: [EventGroupRef]`,
  `explainsNoEligibleGroups: Bool`, `hasLoadedGroups: Bool` (whether the eligible-groups read has landed; the
  creation wizard's hosting-group page shows a disabled placeholder until it has, 2026-11-10),
  `func placeSuggestions(for query: String) async -> [PlaceSuggestion]`. The
  extension in the same file defaults `eligibleGroups` to `[]`, `explainsNoEligibleGroups` to `false` and
  `hasLoadedGroups` to `true`, so an edit
  flow offers no group choice unless a conformer overrides them; `placeSuggestions(for:)` has no default. The create
  and edit view models forward it to `GeocodingService.suggestions(for:near:)`, biased to the draft's spot, else the
  user's position (create) or the game's stored spot (edit).

## Invariants

- `EventDraftEditing` refines `DraftSubmitting` (`lily/Core/UI/Interfaces/DraftSubmitting.swift`: `AnyObject`,
  `Observable`, `associatedtype Issue: Equatable`), so every conformer is an `@Observable` class whose issues are
  `EventDraft.Issue` (`EventDraftEditing.swift`).
- `EventFilterStore.load()` encodes both "nothing saved" and "stored value no longer decodes" as `nil`, never as an
  error; none of its three requirements throws or suspends (`EventFilterStore.swift`).
- Every `EventRepository` write (`join`, `leave`, `create`, `update`) returns the server-side `SportEvent`, never
  `Void`, so callers replace local state with the answer (`EventRepository.swift`).
- `EventRepository.events(in:near:)`: the position applies to `EventScope.upcoming` only; `.joined` and `.group` keep
  the backend's order (doc comment on the requirement; `RemoteEventRepository.listRequest` enforces it).
- `EventRepository.create` is documented idempotent on `EventDraft.clientId`: a repeat answers the same event.

## Side Effects

- None. The directory declares protocols only; the effects belong to the conformers in
  `lily/Features/Events/Implementations/`.

## Verification

- Run: `./scripts/ci.sh unit` from the repository root (the Events suites live under `lilyTests/Events`, e.g.
  `EventDraftEditingTests.swift`, `EventFilterStoreTests.swift`).
