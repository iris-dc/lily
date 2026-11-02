# Inbox

Source: `lily/Features/Inbox/`

## Overview

The inbox feature: the "iskra" conversation pinned as the first row of the Chats tab, holding group and tournament
invites (Accept / Decline) and event and match reminders (open the event or the tournament). Data flows from
`InboxRepository` (the `/api/me/inbox` routes) into `InboxStore`, the one source of the inbox kept for the app's
lifetime and cleared on sign-out, then through `InboxViewModel` to the views. Wire types keep the backend's key names
and `InboxItemKind` tolerates kinds this build does not know (`.unknown`, drawn as nothing and never lighting the
badge). No source files live at this level; the six subdirectories below hold them.

## Subdirectories & Boundaries

- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `InboxRepository` with `page(before:limit:)`,
  `markRead(itemID:)`, `accept(itemID:)`, `decline(itemID:)`; doc-comment contract: ascending pages, monotonic marker,
  idempotent replay.
- Models: [./Models/EGM.md](./Models/EGM.md) - `nonisolated` values: `InboxItem` and `InboxItemKind`, the payloads
  `InvitePayload`, `ReminderPayload`, `TournamentInvitePayload`, `MatchReminderPayload`, the `InviteAnswer` protocol,
  `InboxPage`, `InviteAcceptance`, `InviteDeclination`, `InboxReadPayload`, `InboxReadMarker`, the pure
  `InboxTimeline` and `InboxTimeCaption`, and the `InboxDestination` navigation value.
- Implementations: [./Implementations/EGM.md](./Implementations/EGM.md) - `RemoteInboxRepository` (`GET /api/me/inbox`,
  `PUT /api/me/inbox/read`, `POST /api/me/inbox/{id}/accept` and `/decline`), `MockInboxRepository` mirroring the
  backend's refusals and the monotonic marker, `MockInboxFixtures`.
- State: [./State/EGM.md](./State/EGM.md) - `InboxStore: SessionObserver`: the newest page through `StoreLoader`,
  earlier pages on demand, live items applied in id order, the read marker, `hasUnread`, cleared on sign-out.
- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `InboxViewModel`: timeline rows, one answer per invite
  with one `TRY_AGAIN` retry, a lost answer read back from the inbox before the popup, verdicts reloaded as stale
  cards, acceptance into a group or tournament opening it,
  reminders opening their game or match.
- Views: [./Views/EGM.md](./Views/EGM.md) - `InboxView`, `InboxRow`, `InboxItemRow` with the per-kind cards
  (`TournamentInviteCard`, `MatchReminderCard`) and the shared card parts; plain fills, never glass.
