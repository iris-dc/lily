# Inbox Models

Source: `lily/Features/Inbox/Models/`

## Overview

Plain `nonisolated`, `Sendable` value types for the inbox: the `InboxItem` envelope with its six payloads (group
invite, event reminder, tournament invite, match reminder, event cancelled, group ownership transferred), the wire shapes for a page, an acceptance, a declination
and the read marker, the `InviteAnswer` protocol both invite payloads share, and two pure helpers: `InboxTimeline`
(items to list rows with day separators) and `InboxTimeCaption` (a reminder's time text). Every type decodes with the
backend's key names; nothing here performs I/O.

## Interface

- `InboxItem: Identifiable, Hashable, Codable, Sendable` `[lily/Features/Inbox/Models/InboxItem.swift:InboxItem]`:
  `id`, `kind: InboxItemKind`, `createdAt: Date`, optional `invite: InvitePayload?`, `reminder: ReminderPayload?`,
  `tournamentInvite: TournamentInvitePayload?`, `matchReminder: MatchReminderPayload?`,
  `eventCancelled: EventCancelledPayload?`, `groupOwnershipTransferred: GroupOwnershipTransferredPayload?`;
  synthesized `Codable`;
  `isVisible` (kind known and its payload present), `inviteAnswer: (any InviteAnswer)?` (`invite ?? tournamentInvite`),
  `responding(_:at:) -> InboxItem` (a copy with the invite payload answered).
- `InboxItemKind: WireNamedKind` `[lily/Features/Inbox/Models/InboxItem.swift:InboxItemKind]`: `.groupInvite`
  (`group_invite`), `.eventReminder` (`event_reminder`), `.tournamentInvite` (`tournament_invite`), `.matchReminder`
  (`match_reminder`), `.eventCancelled` (`event_cancelled`), `.groupOwnershipTransferred`
  (`group_ownership_transferred`), `.unknown(String)`; `known`, `wireName` (the lookup is `WireNamedKind`'s default).
- `InviteStatus: WireNamedKind` `[lily/Features/Inbox/Models/InboxItem.swift:InviteStatus]`: `pending`, `accepted`,
  `declined`, `.unknown(String)`; `known`, `wireName`.
- `InvitePayload: Hashable, Codable, Sendable, InviteAnswer` `[lily/Features/Inbox/Models/InboxItem.swift:InvitePayload]`:
  `groupId`, `groupName`, `groupVisibility: GroupVisibility`, `inviterUserId`, `inviterName`, `status` (default
  `.pending`), `expiresAt`, `respondedAt?`; `responding(_:at:)`.
- `ReminderPayload` `[lily/Features/Inbox/Models/InboxItem.swift:ReminderPayload]`: `eventId`, `title`,
  `locationName`, `startsAt`, `groupName?`.
- `TournamentInvitePayload: Hashable, Codable, Sendable, InviteAnswer`
  `[lily/Features/Inbox/Models/TournamentInboxPayloads.swift:TournamentInvitePayload]`: `tournamentId`,
  `tournamentName`, `type: EventType`, `format: TournamentFormat`, `teamSize`, `inviterUserId`, `inviterName`,
  `status`, `expiresAt`, `respondedAt?`; `isTeam` (`teamSize > 1`), `details` (through
  `AppBranding.Tournaments.inviteDetails(type:format:teamSize:)`), `responding(_:at:)`.
- `MatchReminderPayload` `[lily/Features/Inbox/Models/TournamentInboxPayloads.swift:MatchReminderPayload]`:
  `tournamentId`, `tournamentName`, `matchId`, `opponentName`, `scheduledAt`, `locationName?`;
  `destination: TournamentDestination` (id, name and `matchID`).
- `EventCancelledPayload` `[lily/Features/Inbox/Models/DeletionNoticePayloads.swift:EventCancelledPayload]`: `eventId`,
  `title`, `startsAt` — the snapshot of an upcoming game its host's account deletion removed; the event behind it is
  gone (delete-plus-notify), so the card opens nothing.
- `GroupOwnershipTransferredPayload`
  `[lily/Features/Inbox/Models/DeletionNoticePayloads.swift:GroupOwnershipTransferredPayload]`: `groupId`, `groupName` —
  the group the deletion job handed to the caller. Neither notice is answerable (`inviteAnswer` stays `nil`).
- `protocol InviteAnswer` `[lily/Features/Inbox/Models/InviteAnswer.swift:InviteAnswer]`: `status`, `expiresAt`;
  extension `isOpen(now:)` (pending and before its deadline, the one rule) and `statusCaption(now:) -> String?`
  (`nil` through `isOpen`, else `AppBranding.Inbox.joined`, `.declined`, `.expired`; `nil` for an unknown status).
- `InboxItem.caption: String?` `[lily/Features/Inbox/Models/InboxItem+Caption.swift:InboxItem.caption]`: the one-line
  caption per kind, `nil` for `.unknown` or a missing payload. `InboxTimeCaption.text(for:now:calendar:)`
  `[lily/Features/Inbox/Models/InboxItem+Caption.swift:InboxTimeCaption]`; `ReminderPayload.startsAtCaption(now:calendar:)`,
  `MatchReminderPayload.startsAtCaption(now:calendar:)` and `EventCancelledPayload.startsAtCaption(now:calendar:)`
  delegate to it.
- Page and answers `[lily/Features/Inbox/Models/InboxPage.swift]`: `InboxPage` (`items`, `hasMore`, `nextBefore?`,
  `lastReadId?`), `InviteAcceptance` (`item`, `group: SportGroup?`, `tournament: Tournament?`), `InviteDeclination`
  (`item`), `InboxReadPayload: Encodable` (`itemId`, the PUT body), `InboxReadMarker` (`lastReadId`).
- `InboxTimelineRow: Identifiable, Hashable, Sendable` `[lily/Features/Inbox/Models/InboxTimeline.swift:InboxTimelineRow]`:
  `.day(Date)` (id `day-<epoch seconds>` through `ChatDayLabel.rowID(for:)`, shared with `ChatRow`) and
  `.item(InboxItem)` (id = the item's id);
  `InboxTimeline.rows(_:calendar:) -> [InboxTimelineRow]` `[lily/Features/Inbox/Models/InboxTimeline.swift:InboxTimeline]`.
- `InboxDestination: Hashable, Sendable {}` `[lily/Features/Inbox/Models/InboxDestination.swift:InboxDestination]`:
  the empty navigation value that pushes the inbox on the Chats stack.

## Invariants

- An unknown wire name never fails decoding: it becomes `.unknown(name)` and round-trips through `wireName`, for the
  kind and for an invite's status alike; an invite with an unknown status is visible, `isOpen` is false and
  `statusCaption` is `nil`; the card decides by `statusCaption == nil` alone, so it shows no caption and still offers
  Accept and Decline (recorded 2026-11-02, owner's call whether the card should read `isOpen`). `GroupVisibility` stays strict on
  purpose (a binary access rule), so an unknown visibility still fails the page
  `[lily/Features/Inbox/Models/InboxItem.swift:InboxItemKind]`, `[lily/Features/Inbox/Models/InboxItem.swift:InviteStatus]`,
  `[lily/Features/Inbox/Models/InviteAnswer.swift:InviteAnswer.statusCaption]`.
- An item is drawable only when `kind` is known and that kind's payload is present; `.unknown` is never visible
  `[lily/Features/Inbox/Models/InboxItem.swift:InboxItem.isVisible]`.
- `responding(_:at:)` answers `self` unchanged for an item with neither invite payload; answering never mutates, it
  returns a new value with `respondedAt` set to the given date and `expiresAt` kept
  `[lily/Features/Inbox/Models/InboxItem.swift:InboxItem.responding]`,
  `[lily/Features/Inbox/Models/InboxItem.swift:InvitePayload.responding]`,
  `[lily/Features/Inbox/Models/TournamentInboxPayloads.swift:TournamentInvitePayload.responding]`.
- An invite is open only while `status == .pending && expiresAt > now`; a pending invite past `expiresAt` captions as
  expired; `now` is always a parameter, never the wall clock
  `[lily/Features/Inbox/Models/InviteAnswer.swift:InviteAnswer.isOpen]`,
  `[lily/Features/Inbox/Models/InviteAnswer.swift:InviteAnswer.statusCaption]`.
- `InboxTimeline.rows` emits only `isVisible` items, inserts a `.day` row before the first item of each new calendar
  day, and keeps the input order (no sorting) `[lily/Features/Inbox/Models/InboxTimeline.swift:InboxTimeline.rows]`.
- `InboxTimeCaption.text` is determined by `(date, now, calendar)` alone: locale `calendar.locale ?? AppLocale.locale`,
  the relative distance anchored on the event and formatted on `now`
  `[lily/Features/Inbox/Models/InboxItem+Caption.swift:InboxTimeCaption.text]`.
- A tournament invite is a team invite iff `teamSize > 1`
  `[lily/Features/Inbox/Models/TournamentInboxPayloads.swift:TournamentInvitePayload.isTeam]`.
- Every type is `nonisolated`, `Sendable` and `let`-only; `InboxReadPayload` is encode-only
  `[lily/Features/Inbox/Models/InboxPage.swift:InboxReadPayload]`.

## Side Effects

- None: pure value types and formatting.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Inbox/InboxItemCodingTests.swift`, `InboxTimeCaptionTests.swift`,
  `DeletionNoticeTests.swift`).
