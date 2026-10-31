# Inbox State

Source: `lily/Features/Inbox/State/`

## Overview

`InboxStore` is the one source of the caller's inbox, kept for the app's lifetime because the Chats tab badge and the
inbox row need it before the screen is ever opened. It loads the newest page through the shared `StoreLoader` (the
lists' staleness rules, one request at a time, answers for a previous caller dropped), pages earlier items on demand,
applies live items the realtime controller hands it, keeps the read marker, and clears everything on sign-out as a
`SessionObserver`. Items are ascending by id (server ULIDs), so the newest is last.

## Interface

- `@Observable final class InboxStore: SessionObserver` `[lily/Features/Inbox/State/InboxStore.swift:InboxStore]`;
  `init(repository: any InboxRepository, identity: any IdentityProvider, errorCenter: ErrorCenter, logger: any Logging, now: @escaping () -> Date = { .now })`.
- Read-only state: `items: [InboxItem]`, `hasOlder`, `isLoadingOlder`, `lastReadID: String?`; derived `loadFailed`,
  `isLoading`, `hasLoaded` (from the loader), `newest`, `newestVisible` (the last `isVisible` item), `hasUnread`
  `[lily/Features/Inbox/State/InboxStore.swift:InboxStore]`.
- `func loadIfStale() async`, `func reload() async`, `@discardableResult func loadOlder() async -> Bool` (whether
  items not held before arrived), `func apply(_ item: InboxItem)` (a live `inbox_item`), `func replace(_ item: InboxItem)`
  (an answered invite), `func markRead() async`, `func sessionDidEnd()` `[lily/Features/Inbox/State/InboxStore.swift]`.
- `SessionObserver` requires `sessionWillEnd() async`, `sessionDidEnd()` and `sessionDidRestore()`
  `[lily/Core/Auth/Interfaces/SessionObserver.swift:SessionObserver]`; `InboxStore` defines `sessionDidEnd()`.
- Consumers: [ViewModels](../ViewModels/EGM.md) and the `InboxRow` in [Views](../Views/EGM.md).

## Invariants

- A guest has no inbox: `loadIfStale()` and `reload()` clear the store without a request when
  `identity.currentUserID` is `nil` `[lily/Features/Inbox/State/InboxStore.swift:loadIfStale]`,
  `[lily/Features/Inbox/State/InboxStore.swift:reload]`.
- Loads go through one `StoreLoader` (noun "the inbox", category `.inbox`, `version: { 0 }` because no sibling
  screen changes the inbox): once per `AppConfig.Lists.staleAfter` (60 s), `AppConfig.Lists.retryAfterFailure` (10 s)
  after a failure `[lily/Features/Inbox/State/InboxStore.swift:init]`, `[lily/Core/Changes/StoreLoader.swift:StoreLoader]`,
  `[lily/Config/AppConfig.swift:AppConfig.Lists]`.
- The newest page replaces what is held; `lastReadID` only moves forward (`newer`, the greater ULID)
  `[lily/Features/Inbox/State/InboxStore.swift:applyNewestPage]`, `[lily/Features/Inbox/State/InboxStore.swift:newer]`.
- `loadOlder()` runs only when `hasOlder`, none is in flight and a user is signed in; it pages before
  `olderCursor ?? items.first?.id` with `AppConfig.Inbox.pageSize` (50); the answer is dropped if the caller changed
  (`identity.isStillCaller`) or the anchor moved meanwhile (a reload replaced the items, so the page would leave a
  hole); fresh items are merged by id and the list re-sorted ascending
  `[lily/Features/Inbox/State/InboxStore.swift:loadOlder]`, `[lily/Config/AppConfig+Inbox.swift:AppConfig.Inbox.pageSize]`.
- `apply(_:)` replaces a held item by id or inserts it in id order; `replace(_:)` touches only a held item
  `[lily/Features/Inbox/State/InboxStore.swift:apply]`, `[lily/Features/Inbox/State/InboxStore.swift:replace]`.
- `hasUnread` compares the newest visible item's id with the read marker: an item of a kind this build cannot draw
  lights nothing, while `markRead()` still sends `newest.id`, hidden or not
  `[lily/Features/Inbox/State/InboxStore.swift:hasUnread]`, `[lily/Features/Inbox/State/InboxStore.swift:markRead]`.
- `markRead()` sends once per newer newest id: the marker moves locally first, the answer is merged with `newer`, a
  refused PUT is a warning and never a popup, a cancellation is silent
  `[lily/Features/Inbox/State/InboxStore.swift:markRead]`.
- `sessionDidEnd()` clears items, cursor, marker and the loader
  `[lily/Features/Inbox/State/InboxStore.swift:sessionDidEnd]`, `[lily/Features/Inbox/State/InboxStore.swift:clear]`.
- Main-actor isolated by the target's default; observed through `@Observable`.

## Side Effects

- `repository.page(before: nil, limit: 50)` on `loadIfStale` and `reload`; `repository.page(before: anchor, limit: 50)`
  on `loadOlder`; `repository.markRead(itemID:)` on `markRead`
  `[lily/Features/Inbox/State/InboxStore.swift:fetchNewestPage]`, `[lily/Features/Inbox/State/InboxStore.swift:loadOlder]`,
  `[lily/Features/Inbox/State/InboxStore.swift:markRead]`.
- `errorCenter.report(error)` when an earlier page fails; the loader is given the same `errorCenter` for the newest
  page `[lily/Features/Inbox/State/InboxStore.swift:loadOlder]`, `[lily/Features/Inbox/State/InboxStore.swift:init]`.
- Logging under `.inbox`: info "Loaded N inbox items"; debug on an earlier page loaded or dropped, a live item updated
  or arrived, the marker moved; warning on a refused marker; error on a failed earlier page; `.cache` debug on the
  sign-out clearing `[lily/Features/Inbox/State/InboxStore.swift]`.
- No disk, UserDefaults, timers or spawned tasks of its own.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Inbox/InboxStoreTests.swift`, `InboxStoreReadingTests.swift`,
  `InboxStoreConcurrencyTests.swift`).
