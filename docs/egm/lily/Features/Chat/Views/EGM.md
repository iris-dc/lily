# Chat Views

Source: `lily/Features/Chat/Views/`

## Overview

The SwiftUI screens and row primitives of the Chats tab and of one open room: 46 files, no subdirectory. The tab is
`ChatsView` (compact widths) or `ChatsSplitView` (regular widths), both hosting one `ConversationList`, one
destination set and one load task. A room is `ChatView`: a `ChatTranscript` (a bottom-anchored `ScrollView` whose
scroll decisions are delegated to `TranscriptScrollPolicy` through a reference-type `ScrollTracker`) over a
`MessageComposer`. Rows are `ChatRowView` drawing `MessageBubble`, `PendingMessageBubble`, `SystemMessageRow` or
`DaySeparator`; bubbles are plain colour fills from `BubbleInk`, never glass. Polls, quotes, pins and attachments (the
`+` menu and strip while composing, galleries on bubbles, the full-screen viewer whose open and close move two
hierarchies draw from one shared `ViewerHero`) complete the set. Views read `ChatViewModel` and
`AttachmentComposerModel` (`../ViewModels/EGM.md`) and the objects in `../State/EGM.md`; strings come from
`AppBranding`, numbers from `DesignTokens` and `AppConfig.Chat`, identifiers from `AccessibilityIdentifiers`.
Explicit isolation is rare: `@MainActor` on `AttachmentImageLoad`, `ScrollTracker`, `ArrivalTracker` (private to `ChatTranscript.swift`) and the
viewer's private `LoadedPictures`; `nonisolated` on `TranscriptScrollPolicy.Snapshot.init` and on the static
`MessageRemovalTransition.leavingScale(motion:)` and `Animation.messageArrival(_:)`;
everything else takes the app target's default `@MainActor`.

## Interface

Every symbol is `internal` unless marked private; paths are under `lily/Features/Chat/Views/`.

### Screens, transcript and composer

- `[ChatsView.swift:ChatsView]` compact tab root over `AppDependencies`; same file: `View.conversationDestinations
  (dependencies:)` (`groupDestinations`, `InboxDestination`, `SportEvent`) and `View.conversationLoads(dependencies:)`.
- `[ChatsSplitView.swift:ChatsSplitView]` a `NavigationSplitView`: the list in the sidebar, a detail stack bound to
  `navigation.chatPath` showing `InboxView`, a `ChatView` or an `EmptyStateView` for `navigation.selectedConversation`.
- `[ConversationList.swift:ConversationList]` `dependencies`, `selection: ConversationSelection?`, `onOpenInbox`,
  `onOpenRoom: (SportGroup) -> Void`; `InboxRow` over `GroupRowList`, Clear/Delete long-press item, pull-to-refresh.
- `[ChatView.swift:ChatView]` `init(viewModel: ChatViewModel, dependencies:)` (no `onGone`: the split view's
  watcher is the one mechanism); owns the view model and a `ViewerHero` as `@State`; transcript, `ViewerStage`
  overlay, composer inset, toolbar info link (the room offers no menu), empty and failed placeholders through
  `FadingPresence` (`lily/Core/UI/Components/FadingPresence.swift`) on `Animation.firstPageFade`.
- `[ChatTranscript.swift:ChatTranscript]` `init(viewModel:dependencies:hero:)`; `static let endMarkerID`; `@State`
  `ScrollPosition`, `ScrollTracker`, `FirstPageReveal`, the presented items, `shownPinIndex`, `highlightedMessageID`,
  `revealing: Task<Void, Never>?`; `reveal(_ quote:)` (in `+Scrolling.swift`), `loadOlderPage()`. Same file: `nonisolated TranscriptScrollPolicy.Snapshot.init(_: ScrollGeometry)`; `@MainActor
  final class ScrollTracker` (`policy`, `geometry`, `endMarkerY`, `composerLine`, `endIsOnComposer`, `watch(_: String) -> Bool`,
  `record`, `finishWatching`, `logsEveryReport(for:)`).
- `[ChatTranscript+Scrolling.swift:ChatTranscript]` `geometryChanged(to:laidOutRows:)`, `scrollPhaseChanged(from:to:)`,
  `apply(_: TranscriptScrollPolicy.Action)`, `historyEnded()`, `screenArrived()`, `showFirstPage()`, `spinner` (a
  `ProgressView` in a `FadingPresence`),
  `summarizeArrival(of:)`, `log(_:)`; `TranscriptScrollPolicy.Phase.init(_: ScrollPhase)`.
  `[ChatTranscript+Pins.swift:ChatTranscript.pinnedBar]` the `PinnedBar` in the top safe-area bar.
- `[ChatRowView.swift:ChatRowView]` `row: ChatRow`, `viewModel`, `dependencies`, `highlightedMessageID`, tap
  callbacks, `arrivedAt: Date?`; one row with its clock-driven arrival and `MessageContextMenu`. `Equatable` on `row`,
  `highlightedMessageID`, `arrivedAt` and the identity of `viewModel` and `dependencies`; `ChatTranscript` wraps it in
  `equatable()`, so the body run a pin causes leaves unchanged rows as drawn. Accepted limit: a `.day` row reads
  `viewModel.now()` only when its body runs, so a divider on screen across midnight keeps "Today" until the row is
  rebuilt (the room reopened, the row scrolled out of the lazy stack and back); there is no midnight trigger.
- `[MessageComposer.swift:MessageComposer]` `@Bindable viewModel`; `ReplyPreviewBar`, `AttachmentStrip`,
  `AttachmentMenuButton`, a `GrowingTextView` on `draft.text`, send, caption, `PollComposerSheet`.
- `[ReplyPreviewBar.swift:ReplyPreviewBar]` `quote: ReplyQuote`, `onCancel`; an accent `QuoteBar` with a "Replying to"
  caption in `.primary` and a cancel button, an accessibility container `chatReplyPreview`.
- `[PinnedBar.swift:PinnedBar]` `pins`, `shownIndex`, `canUnpin`, `onTap`, `onUnpin`; the accent stripe, the title in
  `.primary`, the quote in `.secondary`.
  `[DaySeparator.swift:DaySeparator]` `day`, `now` (`ChatDayLabel`). `[ChatClearMenuItem.swift:ChatClearMenuItem]`
  `group`, `action`; `View.chatClearConfirmation(for: Binding<SportGroup?>,
  onConfirm:)`, an `.alert(item:)` worded by `ChatClearPrompt`.
- `[TranscriptWidth.swift:EnvironmentValues.transcriptWidth]` `@Entry CGFloat?`; `View.transcriptFraction
  (_:alignment:)`, `View.measuringTranscriptWidth(_:)`. `[MessageArrival.swift:MessageRemovalTransition]`
  `init(for row:, motion: MotionPreference)`, `nonisolated static func leavingScale(motion:) -> CGFloat`;
  `ChatRow.arrivalCorner`; `nonisolated static func Animation.messageArrival(_ motion: MotionPreference) -> Animation?`.
  `[RowReveal.swift:RowReveal]` a `Layout`.

### Bubbles, quotes and polls

- `[MessageBubble.swift:MessageBubble]` `row: MessageRow`, `profile: UserProfileDestination`, `loader`,
  `isQuoteDeleted`, `onTapQuote`, `onTapAttachment: (AttachmentSelection) -> Void`, `onOpenFile`, `onVote:
  ([String]) -> Void`, `onShowVoters`; avatar and name are `NavigationLink(value: profile)` — unless the sender's
  account was deleted (`message.deleted == true`, 2026-11-07): then the avatar is `Tombstone.symbol`, the name is
  `Tombstone.displayName` (the localized "Deleted user") and neither links.
- `[BubbleContent.swift:BubbleContent<Media>]` `text`, `quote`, `isQuoteDeleted`, `own`, `attachmentKinds`,
  `onTapQuote`, `media`; `View.bubbleFill(own:)`, `View.bubbleRow(side:)`, `MessageTimestamp`.
  `[BubbleInk.swift:BubbleInk]` `own` to `primary`, `accent`, `secondary`, `background`.
- `[PendingMessageBubble.swift:PendingMessageBubble]` `message: PendingMessage`, `viewModel`, `onTapQuote`.
  `[SystemMessageRow.swift:SystemMessageRow]` `message`, `viewModel`, `onTap`, `onOpen: (SystemRowDestination) ->
  Void`. `[MessageContextMenu.swift:MessageContextMenu]` `items: MessageMenuItems`, `row`, `viewModel`, `onReport`,
  `onBlock`. `[QuoteBlock.swift:QuoteBlock]` `quote`, `isDeleted`, `own`; the bar in `BubbleInk.accent`, the sender's
  name in `BubbleInk.primary`; `QuoteBar(color:)`; `QuoteStack: Layout` (its spacing a private constant,
  `DesignTokens.Spacing.xs`).
- `[PollBubble.swift:PollBubble]` `poll`, `own`, `isEnabled`, `onVote`, `onShowVoters`; Vote and View votes are
  `lilyTextButton(font: .footnote.weight(.semibold), color: ink.primary, minHeight: DesignTokens.Layout.pollFooterHeight)`.
  `[PollOptionPill.swift:PollOptionPill]` `option`, `display: PollOptionDisplay`, `own`, `onTap`.
  `[PollComposerSheet.swift:PollComposerSheet]` `onSend: (PollDraft) -> Void`; Cancel and Send are
  `lilyToolbarTextButton()`. `[PollVotersSheet.swift:PollVotersSheet]` `message`, `viewModel`, `errorCenter`; Done is
  `lilyToolbarTextButton()`.

### Attachments: composing, galleries and the viewer

- `[AttachmentMenuButton.swift:AttachmentMenuButton]` `attachments: AttachmentComposerModel`, `offersAttachments`,
  `onPoll`; Photo library (`PhotosPicker`), Camera (`CameraPicker` cover), File (`fileImporter`), Poll.
  `[AttachmentStrip.swift:AttachmentStrip]` `attachments`; `AttachmentDraftTile(draft:onRemove:onRetry:)`;
  `ProgressRing(progress:size:)`.
- `[CameraPicker.swift:CameraPicker]` `UIViewControllerRepresentable` over a `UIImagePickerController` camera;
  `onPick: (UIImage) -> Void`; `static isAvailable`. `[QuickLookPreview.swift:View.attachmentQuickLook(_:)]`.
- `[FileAttachmentCard.swift:FileAttachmentCard]` `attachment`, `message`, `loader`, `own`, `onOpen: (URL) -> Void`;
  `FileCard<Trailing>(info: FileCardInfo, own:, isPreparing:, trailing:)`.
  `[ImageAttachmentView.swift:ImageAttachmentView]`, `[VideoAttachmentView.swift:VideoAttachmentView]` `attachment`,
  `message`, `loader`, `onTap`; `PlayBadge`, `DurationBadge`.
- `[AttachmentGallery.swift:AttachmentGallery]` `message`, `loader`, `own`, `alignment`, `onTap: (AttachmentSelection)
  -> Void`, `onOpenFile`; `DraftGallery(drafts:alignment:)`; `AttachmentColumn<Item: GalleryItem, Tile, Card>`;
  `DraftMediaTile`; `GalleryGrid<Tile>(layout: GalleryLayout, ...)`; `EnvironmentValues.galleryCornerRadius`;
  `View.galleryWidth(alignment:)`.
- `[AttachmentImageLoad.swift:AttachmentImageLoad]` `@Observable @MainActor`; `image`, `failed`, `isLoading`;
  `load(_:variant:in:through:available:) async -> UIImage?`. `[AttachmentTile.swift:AttachmentTile]` `image`,
  `isLoading`, `placeholderSymbol`; `LocalImage(url:isPreparing:)` (decoding through `ImageFile.load(_:maxDimension:)`,
  `../Services/EGM.md`, at the thumbnail's bound).
- `[AttachmentViewerSheet.swift:AttachmentViewerSheet]` `init(selection: AttachmentSelection, loader:, hero:
  ViewerHero)`; a `TabView` pager of `ImageViewerPage` and `VideoPlayerPage`, Close, position and share controls, a
  `ViewerDismissPan`; `@State` `ViewerMotion`, `ViewerMoveDriver`, `zoomedIDs`, `ViewerPageLayout` (`frames`, `previews`;
  not observable) and the observable `LoadedPictures` (`byID`, the one store of the full pictures the pages loaded,
  read by `ShareControl`'s body and by `stage()` outside any body).
  `[AttachmentViewerSheet+Motion.swift:AttachmentViewerSheet]` `open()`, `dragged(_:)`,
  `letGo(at:velocity:wasCancelled:)`, `settle()`, `close()`, `curve(fromDrag:) -> UnitCurve`; private
  `followTileThenLeave()`, `handOver()`, `leave()`.
- `[ImageViewerPage.swift:ImageViewerPage]` `attachment`, `message`, `loader`, `preloaded`, `thumbnail`, `onPreview`,
  `onLoaded`, `onZoomed`. `[VideoPlayerPage.swift:VideoPlayerPage]` `attachment`, `message`, `loader`, `isCurrent`,
  `poster` (an `AVPlayer` in a `VideoPlayer`).
- `[ViewerDismissPan.swift:ViewerDismissPan]` `UIGestureRecognizerRepresentable`: `isEnabled`, `onChanged`,
  `onEnded(translation, velocity, wasCancelled)`. `[ViewerHeroSource.swift:View.viewerHeroSource(for:radii:)]`.
  `[ViewerMovingPicture.swift:ViewerMovingPicture]` `hero`, `layer: ViewerLayer`. `[ViewerBackdrop.swift:ViewerBackdrop]`
  `hero`, `layer` (the black of one layer where `ViewerLayer.backdrop` puts it, at `ViewerGeometry.backdropOpacity`).
  `[ViewerStage.swift:ViewerStage]` `hero`.

## Invariants

- `[ChatsView.swift:View.conversationLoads]` `sessionController.restore()` first; loads only when not cancelled and
  `HomeContent(for:) == .overview`, `myGroups.loadIfStale()` before `inbox.loadIfStale()`.
- `[ChatsSplitView.swift:ChatsSplitView]` A selected room not `isAvailable(in: myGroups.groups)` clears
  `navigation.selectedConversation`; each room's `ChatView` is `.id(id)`, so `appear()` and `cancel()` run per room.
- `[ConversationList.swift:ConversationList]` Clear/Delete only from a Chats row's context menu, only when
  `GroupAccess(group:userID:).canChat`, and only after the alert's destructive button; the room has no menu.
- `[ChatView.swift:ChatView]` The placeholder shows only when `rows.isEmpty && !isAwaitingHistory`, Try again only
  when `historyLoadFailed`; `isGone` calls `dismiss()`; the info link is the counterpart's profile, else the
  tournament, else the group, one `chat-title` identifier on the `Group` around the three.
- `[ChatTranscript.swift:ChatTranscript]` The end marker is a zero-height view outside the `LazyVStack`, never lazy;
  the position and both default anchors are `.bottom`; rows are invisible until `firstPageReveal.isShown`, true from
  the start only when `room.hasHistory`. `[ChatTranscript.swift:ScrollTracker]` is a reference type so geometry
  reports never re-run `body`; `endIsOnComposer` is `endMarkerY <= composerLine +
  DesignTokens.Layout.atBottomThreshold`; `watch` accepts only a new, non-nil row id.
- `[ChatTranscript.swift:TranscriptScrollPolicy.Snapshot.init]` `isAtBottom` is always false from raw geometry
  (`geometryChanged` overwrites it with `endIsOnComposer`); `isNearTop` is `offset + top inset <=
  DesignTokens.Layout.olderPageTriggerDistance`.
- `[ChatTranscript+Scrolling.swift:ChatTranscript.geometryChanged]` Compares against the last report the policy saw;
  `canLoadOlder = hasOlder && !isLoadingOlder`; `.loadOlder` calls `policy.willLoadOlder` before loading;
  `.animateToBottom` defers the scroll into a task under `withAnimation(.messageArrival(motion))`, `nil` and so
  instant under Reduce Motion. `Phase.init`:
  `.interacting` is `.touched`, `.idle` is `.resting`, else `.moving`.
- `[ChatTranscript+Scrolling.swift:ChatTranscript.reveal]` Keeps its task in `revealing` (an earlier one cancelled),
  scrolls and highlights only when `viewModel.revealQuoted(id:)` answers true and the task was not cancelled while the
  lookup ran (`Task.isCancelled` checked after the answer), the scroll under `.smooth` or, with
  `!motion.allowsMovement`, no animation; `onDisappear` cancels `opening` and `revealing`, so a lookup still paging
  asks for nothing more; `openViewer` cancels an earlier opening task and sets `viewing` only if not cancelled. Each
  row's removal is `MessageRemovalTransition(for: row, motion: motion)` (`\.motion`).
- `[ChatRowView.swift:ChatRowView]` The curve is `MessageArrivalCurve.standard` while `motion.allowsMovement`, else
  `.still`, whose `settlingDuration` is 0, so under Reduce Motion no row is ever arriving and the reveal is whole from
  the first frame; the arrival clock runs only while `arrivedAt` is set, not settled and within
  `MessageArrivalCurve.settlingDuration`; a context menu only when `MessageMenuItems.items(...).hasEnabledItems`; a
  system row gets a tap only for `.messagePinned` with a `replyTo`.
- `[MessageComposer.swift:MessageComposer]` The menu button only when `attachmentsEnabled || canCreatePolls`
  (`onPoll` nil unless `canCreatePolls`); send `.disabled(!canSend)`; the cooldown caption wins over the counter;
  Return goes through `ReturnKeyPolicy.action(modifiers:canSend:)`; a new `replyTarget` focuses the field.
- `[PinnedBar.swift:PinnedBar]`, `[ChatTranscript+Pins.swift:ChatTranscript.pinnedBar]` The bar exists only with
  pins; the index is normalised by `PinnedBarPosition.shown`; unpin only when `canChangePins`; a tap reveals then
  steps back; the index resets when the pin ids change (`[ChatTranscript.swift:ChatTranscript]`, the `onChange` on
  the pin ids).
- `[MessageBubble.swift:MessageBubble]` Order: `isDeleted`, else `poll`, else content; the tombstone is italic in
  `BubbleInk(own:).secondary` (white at `DesignTokens.Opacity.secondaryOnAccent` on the caller's bubble, never
  `.secondary`, which turns grey on the accent); avatar column only for others,
  avatar and name only on the first bubble of a run, timestamp on the last; the identifier prefers `clientMessageId`.
  A deleted sender (the account tombstone, distinct from `isDeleted`) draws the glyph avatar, the localized name and
  no profile link (2026-11-07).
- `[BubbleContent.swift:View.bubbleFill]` A plain `BubbleInk.background` colour in a rounded rect; a media-only
  bubble (`BubbleFill.standsAlone`) has no fill and no padding. `[QuoteBlock.swift:QuoteStack]` width is the widest
  subview measured as `min(unconstrained, at the offered width)`; subviews stack top to bottom.
- `[PendingMessageBubble.swift:PendingMessageBubble]` Retry, Delete, the failed glyph and the tap gate on `hasFailed`;
  a pending poll is `poll.preview`, disabled. `[MessageContextMenu.swift:MessageContextMenu]` renders only
  `items.offers(...)`; role rules live in `MessageMenuItems`.
- `[PollBubble.swift:PollBubble]` Pills disable once `hasVoted`; single-answer votes on tap, multiple-answer toggles
  `ticked` and sends from Vote (disabled while empty), so `onVote` never gets `[]`; View votes only when `hasVoted &&
  !isAnonymous`. `[PollComposerSheet.swift:PollComposerSheet]` two options to start, anonymous on; remove only above
  `AppConfig.Chat.Polls.minOptions`; Add only while `draft.canAddOption`; Send gated and re-checked on
  `draft.isValid`. `[PollVotersSheet.swift:PollVotersSheet]` dismisses when `voters(of:)` answers `nil`.
- `[AttachmentMenuButton.swift:AttachmentMenuButton]` Media items only when `offersAttachments`, disabled when
  `isFull`; Camera only when `CameraPicker.isAvailable || picksWithoutPicker`; `maxSelectionCount =
  max(remainingSlots, 1)`. `[AttachmentStrip.swift:AttachmentDraftTile]` preview by `draft.kind`, overlay by
  `draft.state`. `[QuickLookPreview.swift:QuickLookPreview]` removes the preview file only on a non-nil to nil change.
- `[AttachmentGallery.swift:AttachmentGallery]` Only `.image` and `.video` become tiles, files become cards, split by
  `GalleryLayout.partition`; the overflow tile stands for every hidden picture. `[AttachmentGallery.swift:GalleryGrid]`
  a single tile fits its aspect capped at `DesignTokens.Layout.galleryMaxHeight`; the "+N" scrim only where
  `layout.showsOverflow(at:)`.
- `[AttachmentImageLoad.swift:AttachmentImageLoad]` `available == false` fails without a download; a cancellation
  leaves `image` and `failed` untouched; undecodable bytes count as failed, as does a picture whose header declares
  more pixels than the cap, which alone logs one `.chat` warning naming the id and the declared size; the picture is
  decoded at `variant.maxDecodedDimension` (512 for a tile, even when the loader hands over the full object, 2048 for
  the viewer). `[VideoAttachmentView.swift:VideoAttachmentView]` passes
  `available: thumbnailUrl != nil`.
- `[AttachmentViewerSheet.swift:AttachmentViewerSheet]` The pan is taken only while `motion.takesDrag` and the
  picture is not zoomed; `stage()` sets `hero.moving` only when `ViewerMotion.movesPicture(hasPicture:hasTile:motion:)`
  holds (a picture, a tile and `\.motion.allowsMovement`), else the pager fades in place and a drag offsets it;
  picture priority `hero.preloaded`, `pictures.byID` (the observable `LoadedPictures`, read by `stage()` outside any body), `hero.thumbnail`, `layout.previews`; the backdrop covers the
  screen unless a picture moves (then `ViewerGeometry.overComposer` only); `presentationBackground(.clear)`.
- `[AttachmentViewerSheet+Motion.swift:AttachmentViewerSheet]` Every move is gated by `ViewerMotion`; `letGo` closes
  only when not cancelled and `ViewerDismissal.closes(drag:velocity:)`; `open()` drives `hero.progress` 1 to 0 on the
  next turn; `close()` drives it to 1 (and `drag` to 0 after a drag); `followTileThenLeave` re-targets `landing`
  only for a tile that moved more than 1 pt; `leave()` dismisses with `disablesAnimations`.
- `[ImageViewerPage.swift:ImageViewerPage]` Zoom settles within `1...DesignTokens.Layout.viewerMaxZoom`; `preloaded`
  skips the load; the stand-in is fetched only without a thumbnail or preload.
  `[VideoPlayerPage.swift:VideoPlayerPage]` plays only while `isCurrent`; a cancelled load creates no player.
  `[ViewerDismissPan.swift:ViewerDismissPan]` single touch, begins only on `ViewerDismissal.beginsDismissal`, the
  pager's scroll view waits for it to fail.
- `[ViewerMovingPicture.swift:ViewerMovingPicture]`, `[ViewerStage.swift:ViewerStage]` Two hierarchies, one
  animation: each draws its half of the same picture from `hero.progress`, `hero.drag`, `hero.landing ?? tile` in a
  `Canvas` sized to its `ViewerLayer` window; non-interactive, hidden from accessibility; the stage is a `ZStack` of
  the `.underComposer` `ViewerBackdrop` and `ViewerMovingPicture`, and draws nothing unless `hero.moving` is set; the
  sheet draws the `.overBars` backdrop the same way (`ViewerLayer.backdrop` holds the side-of-the-line rule).

## Side Effects

- `[ChatsView.swift:View.conversationLoads]` `sessionController.restore()`, `myGroups.loadIfStale()`,
  `inbox.loadIfStale()`. `[ConversationList.swift:ConversationList]` refresh runs `myGroups.reload()`,
  `inbox.reload()`; the alert runs `makeChatHistoryClearer().clear(group)`; the no-rooms button writes
  `navigation.selectedTab = .explore`. Navigation: `openInbox()`, `open(chat:)`, `selectedConversation`, the
  `chatPath` binding, `NavigationLink` values (profiles, tournament, group info, inbox, event).
- `[ChatView.swift:ChatView]` `viewModel.appear()` on task, `cancel()` on disappear, `sceneDidEnterBackground()` on
  `.background`, `loadHistory()`; builds `ViewerHero(logger:)`; `hidesTabBarOnCompact()`.
- `[ChatTranscript.swift:ChatTranscript]` Presents the viewer cover, QuickLook, `PollVotersSheet`, `ReportSheet`
  (`makeReportViewModel(for:title:)`) and the block dialog (`viewModel.block(senderOf:)`); `openViewer` runs
  `KeyboardDismissal.dismissAndWait(atMost: AppConfig.Chat.viewerKeyboardWait)` alongside `hero.preload`; `reveal`
  scrolls (`scrollTo(id:anchor: .center)`) and highlights for `DesignTokens.Duration.messageHighlight`;
  `loadOlderPage` calls `viewModel.loadOlder()` and `policy.didNotLoadOlder()` on false; geometry writes `tracker`
  and `hero.viewport`; `.environment(\.viewerHero, hero)`.
- `[ChatTranscript+Scrolling.swift:ChatTranscript.log]` Debug lines "Transcript ... in group" under `.chat` on
  settle, reports while `tracker.logsThisReport` (`AppConfig.Chat.transcriptOpeningLogWindow` after appear) or on an
  action, following transitions, first-page reveal, phase changes, arrival summaries; `position.scrollTo(id:
  endMarkerID, anchor: .bottom)` and `scrollTo(y:)`.
- `[ChatRowView.swift:ChatRowView]` `Task.sleep` for the arrival's remaining time; `viewModel.vote(in:for:)`;
  `SystemRowDestination.open(through: navigation)`. `[MessageContextMenu.swift:MessageContextMenu]`,
  `[PendingMessageBubble.swift:PendingMessageBubble]` call `startReply(to:)` and `copy(_:)` directly and spawn
  `Task`s into `pin`, `unpin`, `retractVote`, `delete`, `retry`; `discard` runs synchronously under
  `withAnimation(.messageArrival(motion))` (`\.motion`).
  `[SystemMessageRow.swift:SystemMessageRow]` `loadLinkedContent(for:)` on task, `destination(for:)` on tap.
- `[MessageComposer.swift:MessageComposer]` A `.task(id: cooldownUntil)` ticking every `AppConfig.Chat.cooldownTick`
  while cooling down; `send()`, `sendPoll(_:)`, `cancelReply()`; keyboard focus; the poll sheet.
- `[AttachmentMenuButton.swift:AttachmentMenuButton]` Presents `PhotosPicker`, the camera cover, `fileImporter`;
  calls `attachments.add(pickerItems:)`, `add(cameraImage:)`, `add(fileURLs:)`, `noteFileImportFailure`, the
  `...WithoutPicker()` fixtures. `[AttachmentStrip.swift:AttachmentStrip]` `attachments.remove`, `retry`.
  `[CameraPicker.swift:CameraPicker]` the system camera. `[QuickLookPreview.swift:QuickLookPreview]`
  `.quickLookPreview`, `PreviewFiles.remove(previous)`.
- `[FileAttachmentCard.swift:FileAttachmentCard]` `loader.cachedFile(for:)`, `loader.previewFile(for:in:)` with
  progress. `[ImageAttachmentView.swift:ImageAttachmentView]`, `[VideoAttachmentView.swift:VideoAttachmentView]` load
  the `.thumbnail` through `AttachmentLoader` and write `hero?.noteThumbnail(_:for:)`.
  `[AttachmentImageLoad.swift:AttachmentImageLoad.load]` `loader.file(for:variant:in:)` then
  `ImageFile.load(_:maxDimension:)` (`lily/Features/Chat/Services/ImageFile.swift`, a detached ImageIO decode) and
  `loader.logger.warning` for a header over the cap; `[AttachmentTile.swift:LocalImage]` the same decode for a draft's
  file.
- `[AttachmentViewerSheet.swift:AttachmentViewerSheet]` Writes `hero.shownID`, `hero.moving`, `forgetPreloaded()`,
  `endMove()`, `driver.cancel()`; a `ShareLink` (`ShareControl`) whose sheet offers Save Image because the app target
  sets `NSPhotoLibraryAddUsageDescription` (`project.pbxproj`, translated in `lily/InfoPlist.xcstrings`); without it
  iOS 26 withholds the row; installs the pan recognizer.
  `[AttachmentViewerSheet+Motion.swift:AttachmentViewerSheet]` `driver.run` writes `hero.progress`, `hero.drag`,
  `hero.landing` every frame; `hero.log(...)`; `dismiss()` in a `Transaction` with `disablesAnimations`.
  `[ViewerHeroSource.swift:ViewerHeroSource]` `hero.place(TileGeometry, for:)` on frame change, `nil` on disappear.
- `[ImageViewerPage.swift:ImageViewerPage]` Two `AttachmentImageLoad` loads (`.full`, `.thumbnail`).
  `[VideoPlayerPage.swift:VideoPlayerPage]` `loader.previewFile` with progress, `AVPlayer` play and pause,
  `PreviewFiles.remove` on stop and cancellation.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root). The logic these views delegate to is pinned under
  `lilyTests/Chat`: `TranscriptScrollPolicyTests` (+Appends), `TranscriptArrivalsTests`, `MessageArrivalCurveTests`,
  `MessageArrivalTests` (the removal's scale and the spring under Reduce Motion),
  `ReturnKeyPolicyTests`, `PinnedBarPositionTests`, `ChatClearPromptTests`, `ConversationSelectionTests`,
  `BubbleFillTests`, `GalleryLayoutTests`, `AttachmentImageLoadTests`, `AttachmentVariantTests`, `ImageFileTests`,
  `FileAttachmentCardTests`,
  `ViewerMotionTests`, `ViewerDismissalTests`, `ViewerGeometryTests`. Rendering: `./scripts/ci.sh ui`
  (`LilyChatTests` and its `+Area` files in `lilyUITests`).
