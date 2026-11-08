# Inbox Views

Source: `lily/Features/Inbox/Views/`

## Overview

The inbox as a conversation: `InboxView` is the screen (day chips and system cards anchored at the bottom like a chat,
"Load earlier" above the oldest item while an earlier page exists, a spinner, an empty or a failed state), `InboxRow`
is the pinned row on the Chats tab, `InboxItemRow` picks a card per item kind, and `InboxCardParts` plus `InboxItemRow+Tournaments` and
`InboxItemRow+Notices` hold the shared card pieces, the tournament cards and the account-deletion notices. Cards are
plain fills on the surface
colour, never glass, because the list draws many at once. The model is [ViewModels](../ViewModels/EGM.md).

## Interface

- `InboxView(viewModel: InboxViewModel)` `[lily/Features/Inbox/Views/InboxView.swift:InboxView]`: `ContentScreen` with a
  bottom-anchored `ScrollView` and `LazyVStack` in a `readableColumn()`, title `AppBranding.Inbox.title`,
  `hidesTabBarOnCompact()`; rows from `viewModel.rows` (`DaySeparator` for `.day`, `InboxItemRow` for `.item`); the
  "Load earlier" button carries no identifier (no test reads it).
- `InboxRow(inbox: InboxStore, isSelected: Bool = false, onOpen: () -> Void)` `[lily/Features/Inbox/Views/InboxRow.swift:InboxRow]`:
  a `ConversationRow` button with the inbox symbol avatar, the `inbox.hasUnread` dot and the caption
  `inbox.newestVisible?.caption ?? AppBranding.Inbox.emptyCaption`; identifier `AccessibilityIdentifiers.inboxRow`.
- `InboxItemRow(item: InboxItem, viewModel: InboxViewModel)` `[lily/Features/Inbox/Views/InboxItemRow.swift:InboxItemRow]`:
  switches on `item.kind`; private `InviteCard` (group invite) and `ReminderCard` (event reminder).
- `TournamentInviteCard(item:invite: TournamentInvitePayload, viewModel:)` and
  `MatchReminderCard(item:reminder: MatchReminderPayload, viewModel:)`
  `[lily/Features/Inbox/Views/InboxItemRow+Tournaments.swift:TournamentInviteCard]`,
  `[lily/Features/Inbox/Views/InboxItemRow+Tournaments.swift:MatchReminderCard]`.
- `EventCancelledCard(item:payload: EventCancelledPayload, viewModel:)` (a plain card: the warning mark, the bolded
  title sentence, the start-time caption; the event is gone, so there is nothing to open) and
  `GroupOwnershipCard(item:payload: GroupOwnershipTransferredPayload, viewModel:)` (an `InboxOpenCard` with the owner's
  mark whose tap opens the group) `[lily/Features/Inbox/Views/InboxItemRow+Notices.swift:EventCancelledCard]`,
  `[lily/Features/Inbox/Views/InboxItemRow+Notices.swift:GroupOwnershipCard]`.
- Card parts `[lily/Features/Inbox/Views/InboxCardParts.swift]`: `View.inboxCard()` (padding `lg`, full width, ink
  text, the surface fill in the bubble radius); `InviteSentence(inviter:target:)` and `NoticeSentence(name:copy:)` over the shared `SentenceEmphasis`;
  `InboxInviteCard<Mark, Details>(item:viewModel:inviter:target:status: String?, mark:details:)`;
  `InboxInviteActions(item:viewModel:)` (Accept prominent, Decline glass, both regular size, identifiers
  `AccessibilityIdentifiers.inboxAccept(id)` and `inboxDecline(id)`);
  `InboxOpenCard<Details>(item:isBusy:symbol:openLabel:details:action:)` (a tappable card with a chevron whose
  accessibility label names the destination).

## Invariants

- Kind to card: `.groupInvite` needs `item.invite`, `.eventReminder` `item.reminder`, `.tournamentInvite`
  `item.tournamentInvite`, `.matchReminder` `item.matchReminder`, `.eventCancelled` `item.eventCancelled`,
  `.groupOwnershipTransferred` `item.groupOwnershipTransferred`; a known kind with its payload missing and `.unknown`
  render nothing (`EmptyView`); the switch is exhaustive, so a new `InboxItemKind` case fails to compile until it has
  a card `[lily/Features/Inbox/Views/InboxItemRow.swift:InboxItemRow]`.
- An invite shows Accept and Decline only while `statusCaption(now:)` is `nil` (open); otherwise the status text
  takes their place `[lily/Features/Inbox/Views/InboxCardParts.swift:InboxInviteCard]`,
  `[lily/Features/Inbox/Views/InboxItemRow.swift:InviteCard]`,
  `[lily/Features/Inbox/Views/InboxItemRow+Tournaments.swift:TournamentInviteCard]`.
- Accept, Decline and the open cards are disabled while `viewModel.isBusy(item)`, with a spinner hidden from
  accessibility beside the buttons `[lily/Features/Inbox/Views/InboxCardParts.swift:InboxInviteActions]`,
  `[lily/Features/Inbox/Views/InboxCardParts.swift:InboxOpenCard]`.
- `InboxInviteCard` is `.accessibilityElement(children: .contain)` before `AccessibilityIdentifiers.inboxItem(id)`, so
  the buttons keep their own identifiers; `InboxOpenCard` is one button carrying `inboxItem(id)`
  `[lily/Features/Inbox/Views/InboxCardParts.swift:InboxInviteCard]`, `[lily/Features/Inbox/Views/InboxCardParts.swift:InboxOpenCard]`.
- `InviteSentence` formats `AppBranding.Inbox.invitedYou(inviter:group:)` with object-replacement markers (`U+FFFC`
  plus `1` or `2`) and `NoticeSentence` its one-name copy with one, each swapping them for strongly emphasised names
  through `SentenceEmphasis`, so the bold runs land wherever a language puts them
  `[lily/Features/Inbox/Views/InboxCardParts.swift:InviteSentence]`,
  `[lily/Features/Inbox/Views/InboxCardParts.swift:NoticeSentence]`.
- "Load earlier" is a button, not a scroll trigger, shown only while `viewModel.hasOlder` and disabled while
  `isLoadingOlder`; the placeholder draws only when `rows` is empty: a spinner while `isInitialLoad`, the failed state
  while `loadFailed`, else the empty state `[lily/Features/Inbox/Views/InboxView.swift:loadEarlierSlot]`,
  `[lily/Features/Inbox/Views/InboxView.swift:placeholder]`.
- Every time caption takes `viewModel.now()`, never the wall clock `[lily/Features/Inbox/Views/InboxItemRow.swift:ReminderCard]`,
  `[lily/Features/Inbox/Views/InboxItemRow+Tournaments.swift:MatchReminderCard]`,
  `[lily/Features/Inbox/Views/InboxItemRow+Notices.swift:EventCancelledCard]`.

## Side Effects

- `.task { await viewModel.appear() }`, `.refreshable { await viewModel.refresh() }`,
  `.onChange(of: viewModel.newestID) { Task { await viewModel.noteNewItems() } }`, and Load earlier's
  `Task { await viewModel.loadOlder() }` `[lily/Features/Inbox/Views/InboxView.swift:InboxView]`.
- Button actions spawn `Task { await viewModel.accept(item) }`, `decline(item)`, `openEvent(for: item)` and
  `openGroup(for: item)`; `viewModel.openTournament(for: item)` runs synchronously
  `[lily/Features/Inbox/Views/InboxCardParts.swift:InboxInviteActions]`,
  `[lily/Features/Inbox/Views/InboxItemRow.swift:ReminderCard]`,
  `[lily/Features/Inbox/Views/InboxItemRow+Tournaments.swift:MatchReminderCard]`,
  `[lily/Features/Inbox/Views/InboxItemRow+Notices.swift:GroupOwnershipCard]`.
- `InboxRow` calls `onOpen` on a tap; the container decides whether that pushes the inbox or selects it in a split
  view's detail `[lily/Features/Inbox/Views/InboxRow.swift:InboxRow]`.
- No navigation values, error popups, logging or storage of their own; `#Preview` blocks build
  `AppDependencies.makeMock()`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Inbox/InboxItemRowTests.swift`, `DeletionNoticeTests.swift`).
