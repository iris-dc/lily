# Chat

Source: `lily/Features/Chat/`

## Overview

The Chat feature of iskra: the Chats tab (conversation list and inbox entry), one open room (transcript, composer,
replies, polls, pins, attachments and the full-screen attachment viewer), and the data layer under them. The folder
holds no source files of its own; its seven subfolders follow the project's feature-and-layer layout. `Interfaces`
holds the seven protocols every other layer depends on (`ChatRepository`, `ChatHistoryCache`, `AttachmentCache`,
`MediaPreparer`, `AttachmentUploader`, `FrameClock`, `GalleryItem`); `Implementations` the `Remote*` and `Mock*`
repositories, the in-memory room cache and on-disk attachment cache, and the attachment pipeline; `Models` the wire
types (`ChatMessage`, `MessagePage`, `Attachment`, polls, pins, `MessageKind` and `AttachmentKind` tolerating unknown
kinds), the drafts, the per-room `ChatRoomState` and the pure presentation rules; `Services` the four main-actor
services between the screens, the realtime controller and the data layer; `State` the observable objects that
outlive a room (`ChatOutbox`, `UnreadCenter`) or are shared between a chat and its viewer (`ViewerHero`,
`ViewerMoveDriver`); `ViewModels` the two `@Observable` classes (`ChatViewModel`, `AttachmentComposerModel`);
`Views` the SwiftUI screens and row primitives.

The room cache (`ChatHistoryCache`) is the truth that the realtime controller (`lily/Core/Realtime`) and
`ChatViewModel` both write; `RemoteChatRepository` performs no retry of its own (one `client.send` per route, the
caller's `LostRace.attemptTwice` repeats); no file in `Services` calls `ErrorCenter` directly (errors go through
`GroupErrorReporter` in `lily/Features/Groups/Services`). Everything runs without a backend behind the mocks, and
the unit suites live under `lilyTests/Chat` (`./scripts/ci.sh unit`).

## Subdirectories & Boundaries

- Interfaces: [`./Interfaces/EGM.md`](./Interfaces/EGM.md) - the seven protocols with no concrete type among them:
  `ChatRepository` (fourteen async routes: newest/older/newer pages, send, delete, markRead, clearHistory, upload
  tickets, attachment refresh, vote, polls, voters, pin and unpin), `ChatHistoryCache`, `AttachmentCache`,
  `MediaPreparer`, `AttachmentUploader`, `FrameClock`, `GalleryItem`; two extensions supply defaults.
- Models: [`./Models/EGM.md`](./Models/EGM.md) - 46 files of value types: the wire shapes exchanged with Laurel's chat
  routes, `AttachmentCaps` per room kind, drafts, `ChatRoomState` merging pages and live rows in id order, and the
  presentation rules (`ChatTimeline`, `TranscriptScrollPolicy`, gallery layout, viewer geometry and motion, message
  menus); `SystemRowContent`, `SystemRowLinks` and `LinkedContent` are main-actor, every other type is `nonisolated`,
  and all are `Sendable` but `MovingPicture`.
- Implementations: [`./Implementations/EGM.md`](./Implementations/EGM.md) - `RemoteChatRepository` over
  `/api/groups/{id}` chat paths with a fixed fallback `AppError` per route; `MockChatRepository` (rooms above a
  per-caller history floor, echoing writes over the mock realtime bus) built from the pure `MockChatFixtures`;
  `InMemoryChatHistoryCache` and `DiskAttachmentCache` (Caches/Attachments, LRU within 200 MiB, both cleared on
  sign-out); the attachment pipeline (`DeviceMediaPreparer` over image, video and file preparers,
  `URLSessionAttachmentUploader`) with its mocks; `DisplayLinkFrameClock`.
- Services: [`./Services/EGM.md`](./Services/EGM.md) - `AttachmentLoader` (bytes through the cache with presigned-link
  refresh and single-flight downloads, `PreviewFiles` for QuickLook copies), `ChatCatchUp` (pages cached rooms
  forward from their watermark and refreshes polls), `ChatHistoryClearer` (the caller-only clear), `ReadMarkerFlusher`
  (coalesced read-marker pushes).
- State: [`./State/EGM.md`](./State/EGM.md) - `ChatOutbox` (unsent and failed messages per room) and `UnreadCenter`
  (rooms with unseen messages, feeding the tab badge), both `SessionObserver`s cleared on sign-out; `FirstPageReveal`,
  `ViewerHero` and `ViewerMoveDriver`, which runs the viewer's open and close move one frame at a time on one
  `FrameClock` so both hierarchies draw the same frame.
- ViewModels: [`./ViewModels/EGM.md`](./ViewModels/EGM.md) - `ChatViewModel` (one open room: draft, composer, roster,
  read marker, system rows, history paging, live subscription; messages live in the shared cache and outbox) and
  `AttachmentComposerModel` (each picked attachment going from preparing to uploading to uploaded or failed on its own
  task), split into `+Area` extension files.
- Views: [`./Views/EGM.md`](./Views/EGM.md) - `ChatsView` and `ChatsSplitView` (compact and regular Chats tab roots),
  `ConversationList`, `ChatView` with `ChatTranscript` over `MessageComposer`, bubbles, quotes, polls, pins,
  galleries and `AttachmentViewerSheet`; scroll decisions are delegated to `TranscriptScrollPolicy` through a
  reference-type `ScrollTracker`.
