# Chat ViewModels

Source: `lily/Features/Chat/ViewModels/`

## Overview

Two `@Observable final class`es under the app target's default `@MainActor` isolation, each split into `+Area`
extension files. `ChatViewModel` is one open chat room: the room's messages live in the shared `ChatHistoryCache`
(`lily/Features/Chat/Interfaces/ChatHistoryCache.swift`, which the realtime controller writes too) and its unsent
messages in the shared `ChatOutbox` (`../State/EGM.md`); the view model owns only what is local to the screen: the
draft, the attachments being composed, the roster, the read marker, the system rows' content, history paging and
the live subscription. `AttachmentComposerModel` is the pictures, videos and files picked for the message being
composed, each going from preparing to uploading to uploaded or failed on its own task. The screens in
`../Views/EGM.md` read both; every dependency is a protocol or a service type injected through `init`.

## Interface

- `[lily/Features/Chat/ViewModels/ChatViewModel.swift:ChatViewModel.init]` takes `group: SportGroup`,
  `repository: any ChatRepository`, `groups: any GroupRepository`, `links: SystemRowLinks`, `pasteboard: any
  Pasteboard`, `cache: any ChatHistoryCache`, `realtime: RealtimeSessionController`, `catchUp: ChatCatchUp`,
  `unread: UnreadCenter`, `me: MeStore`, `blocks: BlockListStore`, `attachments: AttachmentComposerModel`,
  `attachmentLoader: AttachmentLoader`, `identity: any IdentityProvider`, `reporter: GroupErrorReporter`,
  `clearer: ChatHistoryClearer`, `outbox: ChatOutbox`, `recorder: any InteractionRecorder`, `logger: any Logging`,
  `now`, `sleep`, `tryAgainDelay = AppConfig.API.tryAgainDelay`; builds `SystemRowContent` and `ReadMarkerFlusher`.
- `[ChatViewModel.swift:ChatViewModel]` Observed state: `group`, `draft: MessageDraft`, `attachments`,
  `private(set) members: [GroupMember]`, `isLoadingHistory`, `historyLoadsFinished`, `hasLoadedHistory`,
  `historyLoadFailed`, `olderPageTask: Task<Bool, Never>?`, `cooldownUntil: Date?`, `isGone`, `liveTask`,
  `subscribedEpoch`, `hasRecordedOpen`. Derived: `room: ChatRoomState` (the cache's or an empty stub),
  `pending: [PendingMessage]` (get and set on the outbox), `blockedUserIDs`, `rows: [ChatRow]` (through
  `ChatTimeline.rows`), `hasOlder`, `isCoolingDown`, `cooldownSeconds: Int?`, `canSend`.
- `[ChatViewModel.swift:ChatViewModel]` Lifecycle: `appear() async`, `cancel() async`,
  `sceneDidEnterBackground() async`, `noteRead()`, `mutateRoom(_ change:) -> ChatRoomState?`,
  `report(_ error:, during step:)`.
- `[ChatViewModel+History.swift:ChatViewModel]` `loadHistory() async`, `isAwaitingHistory`, `isLoadingOlder`,
  `oldestID`, `loadOlder() async -> Bool`, `adoptEpoch(_:) async`.
- `[ChatViewModel+Send.swift:ChatViewModel]` `send() async`, `retry(_ message: PendingMessage) async`,
  `discard(_:)`, `delete(_ message: ChatMessage) async`, `updatePending(_ clientMessageID:, _ change:)`,
  `perform(_ draft: MessageDraft) async`.
- `[ChatViewModel+Live.swift:ChatViewModel]` `startLive()`, `handle(_ envelope: RealtimeEnvelope) async`.
- `[ChatViewModel+Attachments.swift:ChatViewModel]` `attachmentsEnabled` (from `MeStore`), `outgoingDraft`,
  `confirmPending(clientMessageID:with:) async`.
- `[ChatViewModel+Clear.swift:ChatViewModel.clearHistory]`, `[ChatViewModel+Conversation.swift:ChatViewModel]`
  `subtitle: String?`, `profile(of row: MessageRow) -> UserProfileDestination`.
- `[ChatViewModel+Events.swift:ChatViewModel]` `systemText(for:)`, `loadLinkedContent(for:) async`,
  `destination(for:) async -> SystemRowDestination?`, `copy(_:)`, `canDelete(_:) -> Bool`.
- `[ChatViewModel+Moderation.swift:ChatViewModel]` `reportTarget(for:) -> ReportTarget`, `block(senderOf:) async`.
- `[ChatViewModel+Pins.swift:ChatViewModel]` `pins: [PinnedMessage]`, `canChangePins`, `canPin(_:)`,
  `pinning(of:) -> MessageMenuItems.Pinning`, `isPinned(_:)`, `pin(_:) async`, `unpin(_ messageID:) async`.
- `[ChatViewModel+Polls.swift:ChatViewModel]` `canCreatePolls`, `sendPoll(_ poll: PollDraft) async`,
  `vote(in:for optionIDs:) async`, `retractVote(in:) async`, `canRetractVote(in:)`,
  `voters(of:) async -> PollVoters?`.
- `[ChatViewModel+Reply.swift:ChatViewModel]` `replyTarget: ReplyQuote?`, `canReply(to:)`,
  `startReply(to row: MessageRow)`, `cancelReply()`, `quoteIsDeleted(_:)`, `revealQuoted(id:) async -> Bool`,
  `dropReply(from clientMessageID:)`.
- `[ChatViewModel.swift:AppError]` extension: `leavesSendOutcomeUnknown`, `leavesVoteOutcomeUnknown`,
  `leavesPinOutcomeUnknown`, `endsRoomAccess`, `isChatRefusal`, `static chatLogLevel(for:) -> LogLevel`.
- `[lily/Features/Chat/ViewModels/AttachmentComposerModel.swift:AttachmentComposerModel.init]` takes `groupID`,
  `caps: AttachmentCaps`, `repository: any ChatRepository`, `uploader: any AttachmentUploader`, `preparer: any
  MediaPreparer`, `cache: any AttachmentCache`, `reporter: GroupErrorReporter`, `logger`,
  `maxPerMessage = AppConfig.Chat.Attachments.maxPerMessage`,
  `maxConcurrentUploads = AppConfig.Chat.Attachments.maxConcurrentUploads` (a `SlotGate`).
- `[AttachmentComposerModel.swift:AttachmentComposerModel]` `private(set) drafts: [AttachmentDraft]`,
  `private maxPerMessage`, `private tasks`; `isEmpty`, `isFull`, `remainingSlots`, `isBusy` (the send reads
  `MessageDraft.uploadedRefs`; the model keeps no `refs` of its own);
  `add(_ source: MediaSource) -> AttachmentDraft?`, `remove(_:)`, `retry(_:)`, `reset()`,
  `seedCache(_ sent:, with stored: [Attachment]) async`; pipeline writes `holds(_:)`, `replace(_:with:) -> Bool`,
  `setState(of:to:)`, `dropRefused(_:_:)`, `finishUpload(_:ref:)`, `failUpload(_:_:)`.
- `[AttachmentComposerModel+Picking.swift:AttachmentComposerModel]` `picksWithoutPicker`,
  `add(pickerItems: [PhotosPickerItem]) async`, `add(cameraImage: UIImage)`, `add(imageData:)`, `add(videoAt:)`,
  `add(fileAt:)`, `add(fileURLs:)`, `addPhotoWithoutPicker()`, `addVideoWithoutPicker()`,
  `addFileWithoutPicker()`, `noteFileImportFailure(_:)`.
- `[AttachmentComposerModel+Upload.swift:AttachmentComposerModel.AttachmentWork]` struct holding the collaborators
  and `weak var owner`; `prepareAndUpload(from: MediaSource) async`, `upload(_ draft:) async`;
  `makeWork(for id:) -> AttachmentWork`.

## Invariants

- `[ChatViewModel.swift:ChatViewModel.room]` The cache is the truth: reads go through `cache.room(for:)`, writes
  through `mutateRoom`, which answers `nil` when the room is not cached so a late answer never re-creates a room
  dropped meanwhile (`ChatCatchUp.loadNewest` caches the stub). `pending` is a view on the `ChatOutbox`, never a copy.
- `[ChatViewModel.swift:ChatViewModel.appear]` Order: record the open once, `setOpenRoom` and `ensureSubscribed`,
  `loadHistory()`, then only if neither `Task.isCancelled` nor `isGone`: `startLive()`, `readMarker.opened()`,
  the roster. `cancel()` ends the live task, cancels the older page in flight, closes the open room through
  `RealtimeSessionController.closeRoom` (only while it is still this screen's) and flushes the marker; it never
  compacts, the controller does once another room opens.
- `[ChatViewModel+History.swift:ChatViewModel.adoptEpoch]` `subscribedEpoch` only grows (`guard epoch >
  subscribedEpoch`); a newer epoch moves the controller, resubscribes and catches up once, and re-registers the open
  room at the new epoch only while the live task runs and `realtime.openRoom` is still this room (an iPad switch where
  the next room registered first keeps that room open).
- `[ChatViewModel+History.swift:ChatViewModel.loadHistory]` A cached room (`room.hasHistory`) catches up from the
  watermark, else the newest page is loaded; `historyLoadFailed` is set only when the error is not a cancellation
  and does not end room access. `isAwaitingHistory` is `isLoadingHistory || (!hasLoadedHistory &&
  !historyLoadFailed)`.
- `[ChatViewModel+History.swift:ChatViewModel.loadOlder]` One older page in flight at a time: answers `false` while
  `olderPageTask` is set, `hasOlder` is false or the caller is cancelled; the slot is released inside the task, and a
  page cancelled by `cancel()` reports nothing (`report` is quiet for cancellations).
- `[ChatViewModel.swift:ChatViewModel.canSend]` `outgoingDraft.isValid && !attachments.isBusy && !isCoolingDown &&
  !isGone`. `[ChatViewModel+Send.swift:ChatViewModel.send]` is optimistic: the bubble is appended and the draft and
  composer reset before the request; the client id is kept through every retry. `retry` finds the bubble by
  `clientMessageID`, requires `hasFailed` and no cooldown.
- `[ChatViewModel+Send.swift:ChatViewModel.perform]` Writes repeat one `TRY_AGAIN` through
  `LostRace.attemptTwice(delay: tryAgainDelay)` (send, pins, vote). An unknown outcome (`.network`,
  `.messageSendFailed`) catches up before the bubble is marked failed; a 429 sets `cooldownUntil` from `retryAfter`
  or `AppConfig.Chat.rateLimitCooldownFallback`; `.replyTargetNotFound` drops the quote from the failed bubble.
- `[ChatViewModel+Send.swift:ChatViewModel.delete]` The tombstone is written first; a failure restores the message
  unless the backend answered `.messageNotFound`.
- `[ChatViewModel.swift:ChatViewModel.report]` Cancellation is silent; `.notAMember` and `.groupNotFound`
  (`endsRoomAccess`) remove the group locally and set `isGone`; refusals in `isChatRefusal` log at warning, faults at
  error; everything but cancellation reaches `GroupErrorReporter.report`.
- `[ChatViewModel+Live.swift:ChatViewModel.handle]` An own live echo (`clientMessageId` and sent by the current
  user) confirms the pending bubble; `memberLeft` naming the caller or `groupDeleted` sets `isGone`;
  `tournamentChanged`, `matchUpdated`, `messageDeleted`, `membershipChanged`, `inboxItem`, `unknown` change nothing
  here.
- `[ChatViewModel+Events.swift:ChatViewModel.canDelete]` `ChatMessage.isLiveMemberMessage` (not deleted, not
  system; the one predicate the three share) and the sender or `GroupAccess.canEdit`.
  `[ChatViewModel+Pins.swift:ChatViewModel.canPin]` `isLiveMemberMessage` and `GroupAccess.canPin(in:)`; `pins`
  leaves out messages the room marks deleted. `[ChatViewModel+Reply.swift:ChatViewModel.canReply]`
  `isLiveMemberMessage`.
- `[ChatViewModel+Pins.swift:ChatViewModel.changePins]` A pin or unpin answered applies the answer's pins and adopts
  its epoch; a pin then catches up once for the backend's note. A `.network` or `.pinFailed`
  (`leavesPinOutcomeUnknown`) is read back through `LostAnswer` with one `catchUp.catchUp(groupID:)` (every page
  carries `pins`): the room the catch-up answered showing `wanted` for the id in its `pins` means landed and nothing
  is reported; a catch-up answering `nil` (the room left the cache meanwhile) is unresolved, never judged on `room`'s
  empty stub; otherwise the failure reaches `report`. A refusal catches up nothing.
- `[ChatViewModel+Polls.swift:ChatViewModel.vote]` Optimistic `applyPoll(before.voting(optionIDs))`. A failure whose
  outcome is unknown (`leavesVoteOutcomeUnknown`) is read back through `LostAnswer` with
  `repository.polls(groupID:messageIDs:)`: the state the backend names replaces the shown poll whatever it says, and
  `myVotes` equal to the choice means landed (no popup); `before` returns only when the settlement is `.unresolved` (a
  refusal, a failed refresh, no state named). `retractVote` is a vote for `[]`.
- `[ChatViewModel+Reply.swift:ChatViewModel.revealQuoted]` Loads at most `AppConfig.Chat.maxReplyLookupPages`
  older pages; an in-flight `olderPageTask` is awaited and not counted, and ends the lookup when it was cancelled
  (the screen left); "before the history" is `id < oldestID`.
- `[ChatViewModel+Attachments.swift:ChatViewModel.confirmPending]` The bubble's files are seeded into the cache
  under the stored ids before the bubble is removed.
- `[AttachmentComposerModel.swift:AttachmentComposerModel.add]` Refused when `isFull` (`drafts.count >=
  maxPerMessage`); pickers take `prefix(remainingSlots)`. `isBusy` is any draft `isInFlight`. `retry` requires
  `hasFailed` and `holds(id)`, marks the slot `.uploading(0)` and hands the draft as received to the upload.
- `[AttachmentComposerModel.swift:AttachmentComposerModel.seedCache]` Each stored id is claimed in `seeded` before
  the first await, so the answer and the live echo settling the same message copy and delete once.
- `[AttachmentComposerModel+Upload.swift:AttachmentWork]` Holds the owner weakly; the owner is resolved only for
  state writes; a slot removed meanwhile is left alone and an owner that is gone deletes the prepared files;
  cancellation is silent. Order: `slots.acquire()`, `holds` check, `repository.requestUpload` ticket,
  `uploader.upload` with progress, `finishUpload`. `source.ownedFile` is removed after the preparer, whatever the
  outcome.
- `[AttachmentComposerModel.swift:AttachmentComposerModel.deinit]` Cancels every task and deletes every draft's
  files; `reset()` empties `drafts` before a send, so a sent message's files are never deleted here.
  `failUpload` re-raises `.attachmentTooLarge` with this room's `caps`.

## Side Effects

- `[ChatViewModel]` Network through `ChatRepository` (`send`, `delete`, `older`, `pin`, `unpin`, `vote`, `voters`,
  `polls`), `GroupRepository.members`, `ChatCatchUp.catchUp` and `loadNewest`, `ChatHistoryClearer.clear`,
  `BlockListStore.block`.
- `[ChatViewModel]` Realtime: `RealtimeSessionController.setOpenRoom`, `closeRoom`, `ensureSubscribed`, `moveEpoch`,
  `removeGroupLocally`, and `envelopes(for:)` consumed by `liveTask`. Cache: `ChatHistoryCache.update`, `room`.
  Outbox writes through `pending`. Read marker through `ReadMarkerFlusher.opened`, `flush`, `noteRead`,
  `reset`. `SystemRowContent.recordChange(for:)` on live messages; `recorder.record(.chatOpened)` once;
  `pasteboard.copy`; `GroupErrorReporter.report` for the popup (and the terms sheet on `TERMS_REQUIRED`).
- `[ChatViewModel]` Logs under `.chat` (`.cache` for "Room cache hit/miss for group"): "Message sent", "deleted in
  group", "Send outcome unknown for", "Send landed for", "Blocked user", "pinned in group", "unpinned in group",
  "Vote of", "Vote in poll <id> outcome unknown", "Pinning message <id> outcome unknown", "landed despite", "Could
  not read back after", "Quoted message", "Roster unavailable for group", "Catch-up after",
  "Older page before", "<step> failed in group <id>" (at `AppError.chatLogLevel(for:)`). Tests pin these as count plus fragment.
- `[AttachmentComposerModel]` One `Task` per draft in `tasks`, cancelled by `remove`, `reset` and `deinit`. Disk:
  `deleteLocalFiles()`, `FileManager.default.removeItem(at: ownedFile)`, `AttachmentCache.store(copying:for:variant:)`.
  Network: `ChatRepository.requestUpload`, `AttachmentUploader.upload`. Media: `MediaPreparer.prepareImage`,
  `prepareVideo`, `prepareFile`; `PhotosPickerItem.loadTransferable`; `UIImage.jpegData`. `GroupErrorReporter.report`
  on a refusal and an upload failure. Logs under `.chat`: "uploaded as" (info), "upload failed" (error), "could not
  be prepared", "could not seed the cache", "The files importer failed", "could not be loaded" (warning),
  "Attachment dropped", "prepared for a slot that is gone: files deleted", "uploaded for a composer that is gone: files
  deleted" (debug).

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root). The matching suites live under `lilyTests/Chat`: the
  sixteen `ChatViewModel*Tests` files, `AttachmentComposerModelTests` and `AttachmentComposerModelKindTests`.
