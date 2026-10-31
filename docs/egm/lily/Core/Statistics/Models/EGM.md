# Statistics Models

Source: `lily/Core/Statistics/Models/`

## Overview

The wire shape of a reported interaction and of the batch it travels in. By construction an `Interaction` carries ids,
types and flags only: never a coordinate, an amount, a date range, a query or free text. Every type is `nonisolated`
and `Sendable`; none performs I/O.

## Interface

- `nonisolated enum InteractionKind: String, Codable, Sendable`: `event_viewed`, `filter_applied`,
  `presentation_changed`, `group_viewed`, `group_search_performed`, `chat_opened`, `tournament_viewed`
  [`lily/Core/Statistics/Models/Interaction.swift:InteractionKind`].
- `nonisolated struct Interaction: Encodable, Equatable, Sendable`: `kind`, `occurredAt: Date`, and the optionals
  `eventId`, `eventType: EventType?`, `hostUserId`, `filter: FilterSummary?`, `presentation: String?`, `groupId`,
  `groupVisibility: GroupVisibility?`, `hasQuery: Bool?`, `resultCount: Int?`, `tournamentId`,
  `tournamentFormat: TournamentFormat?`; factories `viewed(_ event: SportEvent, at:)`,
  `filterApplied(_ filter: EventFilter, at:)`, `presentationChanged(_ presentation: EventsPresentation, at:)`,
  `groupViewed(_ group: SportGroup, at:)`, `groupSearchPerformed(hasQuery:resultCount:at:)`,
  `chatOpened(groupID:at:)`, `tournamentViewed(_ tournament: Tournament, at:)`
  [`lily/Core/Statistics/Models/Interaction.swift:Interaction`].
- `nonisolated struct FilterSummary: Encodable, Equatable, Sendable`: `types: [String]`, `maxDistanceMeters: Double?`,
  `hasMaxPrice: Bool`, `skillLevel: SkillLevel?`, `hasDateWindow: Bool`, `openSpotsOnly: Bool`;
  `init(_ filter: EventFilter)` [`lily/Core/Statistics/Models/FilterSummary.swift:FilterSummary`].
- `nonisolated struct InteractionBatch: Encodable, Equatable, Sendable { let interactions: [Interaction] }` (the body
  of `POST /api/interactions` per its doc comment) and
  `nonisolated struct InteractionReceipt: Decodable, Equatable, Sendable { let accepted: Int }`
  [`lily/Core/Statistics/Models/InteractionBatch.swift:InteractionBatch`, `InteractionReceipt`].

## Invariants

- `FilterSummary.types` is the filter's event types as `wireName`s, sorted, cut to
  `AppConfig.Statistics.maxFilterTypes`, so equal selections encode equally and the list never exceeds what Laurel
  accepts; `hasMaxPrice` is `maxPrice != nil` and `hasDateWindow` is `dateWindow != nil`, never the values
  [`FilterSummary.swift:FilterSummary.init(_:)`].
- Each factory fills only the fields of its kind: `viewed` sets `eventId`, `eventType`, `hostUserId`; `groupViewed`
  sets `eventType`, `groupId`, `groupVisibility`; `groupSearchPerformed` sets `hasQuery` and `resultCount`, never the
  query; `tournamentViewed` sets `eventType`, `tournamentId`, `tournamentFormat`
  [`Interaction.swift:Interaction.viewed(_:at:)`, `Interaction.swift:Interaction.groupSearchPerformed(hasQuery:resultCount:at:)`].
- Wire names are snake_case to match the backend's `InteractionKind` [`Interaction.swift:InteractionKind`].

## Side Effects

- None (pure values).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Statistics`)
