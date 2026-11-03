# Chat State

Source: `lily/Features/Chat/State/`

## Overview

Five main-actor objects, four of them `@Observable` (`ViewerMoveDriver` is not), that live beside or outlive a `ChatViewModel` (`../ViewModels/EGM.md`) and are read by the
chat views (`../Views/EGM.md`). Two are process-wide and session-bound: `ChatOutbox` keeps every room's unsent and
failed messages so a send that fails after Back is still a failed bubble on the next open, and `UnreadCenter` says
which rooms hold messages the caller has not seen (the Chats tab badge and the row dots). Three are per screen:
`FirstPageReveal` decides when a transcript shows its rows, `ViewerHero` is what a chat and its attachment viewer
share for the viewer's open and close move, and `ViewerMoveDriver` runs that move one frame at a time on one clock
so both hierarchies draw the same frame. The app target's default isolation is `@MainActor`; the two
`SessionObserver`s rely on it, the other three are marked explicitly.

## Interface

- `[lily/Features/Chat/State/ChatOutbox.swift:ChatOutbox]` `@Observable final class ChatOutbox: SessionObserver`.
  Private `rooms: [String: [PendingMessage]]`. `messages(in groupID:) -> [PendingMessage]`;
  `replace(_ messages:, in groupID:)` (the room's unsent messages as its screen now holds them);
  `discardAll(in groupID:)` (drops the room's messages with their files); `sessionDidEnd()`.
- `[lily/Features/Chat/State/UnreadCenter.swift:UnreadCenter]` `@Observable final class UnreadCenter: SessionObserver`.
  `private(set) var unreadGroupIDs: Set<String>`; `count: Int` (what the tab badge shows); `hasUnread(groupID:) -> Bool`;
  `apply(groups: [SportGroup])` (a Mine load, merged, not copied); `markUnread(groupID:messageID:)`;
  `markRead(groupID:upTo messageID: String? = nil)`; `sessionDidEnd()`. Private `liveUnreadIDs` and `readIDs`
  (newest live-unread and newest read message id per room).
- `[lily/Features/Chat/State/FirstPageReveal.swift:FirstPageReveal]` `@Observable @MainActor final class FirstPageReveal`.
  `init(isShown: Bool, sleep: @escaping Sleep = systemSleep)`; `private(set) var isShown: Bool`;
  `@ObservationIgnored private(set) var isSettled`. `noteLayout(hasRows:onSettled:)`, `arrived()`, `departed()`,
  `historyEnded(hasRows:loaded:onSettled:)`, `showsSpinner(hasRows:isAwaitingHistory:) -> Bool`, `show()`.
- `[lily/Features/Chat/State/ViewerHero.swift:ViewerHero]` `@Observable @MainActor final class ViewerHero`,
  `init(logger: (any Logging)? = nil)`. Observed: `shownID: String?`, `progress: CGFloat` (0 fitted to the screen,
  1 on its tile), `drag: CGFloat`, `landing: CGRect?`, `moving: MovingPicture?`. `@ObservationIgnored`:
  `tiles: [String: TileGeometry]` (private(set)), `viewport: CGRect?`, `preloaded: [String: UIImage]` (private(set)),
  a weak thumbnail table. Methods: `place(_ geometry: TileGeometry?, for ids: [String])`,
  `preload(_ attachment: Attachment, in message: ChatMessage, through loader: AttachmentLoader) async`,
  `forgetPreloaded()`, `endMove()`, `log(_:)`, `static describe(_ rect: CGRect?) -> String`,
  `noteThumbnail(_ image: UIImage?, for id:)`, `thumbnail(for id:) -> UIImage?`.
- `[lily/Features/Chat/State/ViewerHero.swift:EnvironmentValues.viewerHero]` `@Entry var viewerHero: ViewerHero?`;
  `nil` where no viewer opens (a preview, an unsent bubble).
- `[lily/Features/Chat/State/ViewerMoveDriver.swift:ViewerMoveDriver]` `@MainActor final class ViewerMoveDriver`.
  `init(clock: any FrameClock)`; `convenience init()` uses `DisplayLinkFrameClock`
  (`lily/Features/Chat/Implementations/DisplayLinkFrameClock.swift`);
  `run(duration:curve:now: = CACurrentMediaTime(), apply: (Double) -> Void, completion: () -> Void)`; `cancel()`;
  `nonisolated static fraction(elapsed:duration:curve:) -> Double`; `step(at timestamp:)`.

## Invariants

- `[ChatOutbox.swift:ChatOutbox.replace]` An empty list forgets the room (`rooms[groupID] = nil`), so `rooms` holds
  only rooms with unsent messages.
- `[ChatOutbox.swift:ChatOutbox.discardAll]` and `[ChatOutbox.swift:ChatOutbox.sessionDidEnd]` call
  `PendingMessage.deleteLocalFiles()` on every dropped message before forgetting it: a failed picture's files never
  outlive its bubble, and one account's unsent pictures never stay for the next.
- `[UnreadCenter.swift:UnreadCenter.isUnread]` "Newer" is a string comparison of message ids throughout (`>`,
  `max`); the comment states ids sort like ULIDs. A room is unread when a live mark is newer than the snapshot's
  `membership.lastReadMessageId`; otherwise only when `group.hasUnread` and either nothing was read here or
  `group.lastMessageId` is newer than the newest id read here.
- `[UnreadCenter.swift:UnreadCenter.apply]` A Mine snapshot is merged, not copied: `unreadGroupIDs` is recomputed
  through `isUnread`, and live marks survive only for rooms still unread.
- `[UnreadCenter.swift:UnreadCenter.markRead]` Removes the room and its live mark; `readIDs` only grows (`max`).
  `[UnreadCenter.swift:UnreadCenter.sessionDidEnd]` clears all three maps.
- `[FirstPageReveal.swift:FirstPageReveal.noteLayout]` Ignored once shown or without rows. Each layout pass restarts
  the quiet timer (`AppConfig.Chat.firstPageRevealQuiet`); the limit timer
  (`AppConfig.Chat.firstPageRevealLimit`) starts once, on the first pass, and is never restarted.
- `[FirstPageReveal.swift:FirstPageReveal.settles]` A timer that fires marks `isSettled` and calls `onSettled` only
  when it is the limit or the screen has arrived (`!isArriving`); a cancelled sleep, a cancelled task or a shown
  state fires nothing. `[FirstPageReveal.swift:FirstPageReveal.arrived]` runs `onSettled` if the layout settled while
  the push ran; `departed()` makes the way back a transition again.
- `[FirstPageReveal.swift:FirstPageReveal.historyEnded]` Rows wait for a quiet layout; no rows and `loaded` shows at
  once; no rows and not loaded (a failed page) stays hidden. `showsSpinner` is `!isShown` with rows, else
  `isAwaitingHistory`. `[FirstPageReveal.swift:FirstPageReveal.show]` cancels both timers and drops `onSettled`.
- `[ViewerHero.swift:ViewerHero]` Only `shownID`, `progress`, `drag`, `landing` and `moving` are observed; tile
  places, the viewport, thumbnails and preloaded pictures are `@ObservationIgnored` because tiles write them on
  every layout pass and scroll. Thumbnails are held in an `NSMapTable.strongToWeakObjects()` table, so a tile that
  is gone frees its decoded picture.
- `[ViewerHero.swift:ViewerHero.preload]` Only `.image` attachments not already preloaded; bounded by
  `Deadline.within(AppConfig.Chat.viewerPreloadWait)`; a result after `Task.isCancelled` is dropped.
- `[ViewerHero.swift:ViewerHero.endMove]` Resets `moving`, `landing`, `progress = 1`, `drag = 0`: the viewer is gone
  and the composer is whole.
- `[ViewerMoveDriver.swift:ViewerMoveDriver.run]` A new run cancels the one before, whose completion never comes;
  `apply` is called from the next frame on. `[ViewerMoveDriver.swift:ViewerMoveDriver.fraction]` clamps the elapsed
  share to `0...1` and answers 1 for a non-positive duration. `[ViewerMoveDriver.swift:ViewerMoveDriver.step]` applies
  the fraction every frame; the frame at or past the end is exactly 1, and the completion runs once, after `cancel()`.

## Side Effects

- `[ChatOutbox.swift:ChatOutbox]` Deletes local files through `PendingMessage.deleteLocalFiles()` in `discardAll`
  and `sessionDidEnd`. No network, disk reads or logging.
- `[UnreadCenter.swift:UnreadCenter]` In-memory only; mutates the observed `unreadGroupIDs` that the badge and rows
  read. No network, disk or logging.
- `[FirstPageReveal.swift:FirstPageReveal.settles]` Spawns a `Task` per timer that awaits the injected `sleep`
  (default `systemSleep`); `noteLayout` and `show` cancel them.
- `[ViewerHero.swift:ViewerHero.preload]` Loads the full picture through `AttachmentImageLoad.load(..., through:
  loader)` (`AttachmentLoader`) and keeps the decoded `UIImage` in `preloaded` until `forgetPreloaded()`.
- `[ViewerHero.swift:ViewerHero.log]` Logs at debug under `.chat` ("Viewer ..."), ids and geometry only: a tile move
  of the shown attachment (`place`) and the preload outcome with the wait in ms (`preload`).
- `[ViewerMoveDriver.swift:ViewerMoveDriver]` Starts and stops the injected `FrameClock` (`clock.start`,
  `clock.stop`); reads `CACurrentMediaTime()` as the default start; calls `apply` once per frame and `completion`
  once.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root). The matching suites live under `lilyTests/Chat`:
  `ChatViewModelOutboxTests`, `UnreadCenterTests`, `FirstPageRevealTests`, `ViewerHeroTests`,
  `ViewerMoveDriverTests`.
