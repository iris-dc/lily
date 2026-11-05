# People Views

Source: `lily/Features/People/Views/`

## Overview

Five views: `PersonRow` (a roster or participant row that links to a person's profile unless it is the caller),
`SharedGroupRow` (a "Groups in common" row linking to the group's detail), `SharedEventRow` (a "Games together" row, no
link), `SharedTournamentRow` (a "Tournaments together" row linking to the tournament's detail) and `UserProfileView`
(the profile screen: avatar, name, Message when allowed, the bio, the three shared sections). Loading and writes belong to
[ViewModels](../ViewModels/EGM.md); the views log nothing, report nothing and mutate no store.

## Interface

- `PersonRow<Badge: View>(userID: String, displayName: String, isSelf: Bool, identifier: String, badge: () -> Badge)`
  `[lily/Features/People/Views/PersonRow.swift:PersonRow]`: pushes `UserProfileDestination(userId:displayName:)`
  (context `.standalone`); the identifier is caller-supplied; the name comes from `AppBranding.People.name(_:isSelf:)`.
- `SharedGroupRow(group: GroupSummary)` `[lily/Features/People/Views/SharedGroupRow.swift:SharedGroupRow]`:
  `GroupRowContent(name:visibility:caption:hasUnread: false)` in a `NavigationLink(value: group.ref)`; identifier
  `AccessibilityIdentifiers.groupRow(group.id)` (`group-row-<id>`).
- `SharedEventRow(event: EventSummary)` `[lily/Features/People/Views/SharedHistoryRows.swift:SharedEventRow]`:
  `GroupRowContent(name: title, visibility: nil, caption: event.caption, hasUnread: false, avatarSymbol:
  event.type.symbolName)`, one accessibility element (`children: .combine`) with identifier
  `AccessibilityIdentifiers.sharedEventRow(event.id)` (`shared-event-row-<id>`); no link.
- `SharedTournamentRow(tournament: TournamentSummary)` `[lily/Features/People/Views/SharedHistoryRows.swift:SharedTournamentRow]`:
  the same content with `DesignTokens.Symbols.tournament` in the mark, in a `NavigationLink(value: tournament.destination)`;
  identifier `AccessibilityIdentifiers.tournamentRow(tournament.id)` (`tournament-row-<id>`).
- `UserProfileView(viewModel: UserProfileViewModel, dependencies: AppDependencies)`
  `[lily/Features/People/Views/UserProfileView.swift:UserProfileView]`:
  `ContentScreen` with a `ScrollView` in a `readableColumn()`, inline title `viewModel.displayName`; a
  `navigationDestination(item: $viewModel.openedConversation)` building `ChatView` on this stack, so Back from the chat
  Message opened returns to the profile (before 2026-11-05 it was pushed on the Chats tab and Back landed on the Chats
  list); private `header`,
  `messageButton` (a `BusyButton` with `lilyProminentButton()`, identifier `AccessibilityIdentifiers.profileMessage`,
  `profile-message`), `content` (the state switch), `loaded(_:)` (the bio `Text`, identifier
  `AccessibilityIdentifiers.profileBio`, then the three sections), `section(_:orElse:_:row:)` (a `SectionTitle` over a
  `LazyVStack` of rows each followed by `AvatarRowDivider()`, or over the empty note; no container identifier),
  `loadFailed`, `note(_:)`.
- Copy: `AppBranding.People.message`, `sharedGroupsTitle`, `noSharedGroups`, `sharedEventsTitle`, `noSharedEvents`,
  `sharedTournamentsTitle`, `noSharedTournaments`, `loadFailedTitle`, `AppBranding.Groups.tryAgain`
  `[lily/Features/People/Views/UserProfileView.swift:UserProfileView]`.

## Invariants

- `PersonRow` for the caller (`isSelf`) renders plain content with no link; otherwise the content sits in a
  `NavigationLink` with `.buttonStyle(.plain)`, `.lilyHoverable()` and the identifier on the link itself (a
  `.contextMenu` around the row would swallow one applied outside) `[lily/Features/People/Views/PersonRow.swift:body]`;
  the content is `.accessibilityElement(children: .combine)` with a one-line name and `badge().fixedSize()`
  `[lily/Features/People/Views/PersonRow.swift:content]`.
- `SharedGroupRow` always passes `hasUnread: false` and links to `group.ref` (`isDeleted: false`)
  `[lily/Features/People/Views/SharedGroupRow.swift:body]`, `[lily/Features/People/Models/GroupSummary.swift:ref]`.
- The Message button renders only `if viewModel.canMessage`; its spinner follows `viewModel.isStartingConversation`
  `[lily/Features/People/Views/UserProfileView.swift:body]`, `[lily/Features/People/Views/UserProfileView.swift:messageButton]`.
- State to content: `.loading` one spinner under the header (no section titles yet); `.failed` the failed state with
  Try again; `.loaded` the bio when there is one, then the three sections in the order groups, games, tournaments, each
  with its rows in the order received (no filtering or sorting), each row followed by `AvatarRowDivider()`, or the
  section's "none yet" note `[lily/Features/People/Views/UserProfileView.swift:content]`,
  `[lily/Features/People/Views/UserProfileView.swift:loaded]`, `[lily/Features/People/Views/UserProfileView.swift:section]`.
- The rows container carries no accessibility element or identifier of its own, so each row keeps
  its `group-row-<id>`, `shared-event-row-<id>` or `tournament-row-<id>` `[lily/Features/People/Views/UserProfileView.swift:section]`.
- No `LayoutMode` references in the four files.

## Side Effects

- `.task { await viewModel.load() }` `[lily/Features/People/Views/UserProfileView.swift:body]`; the Message
  `BusyButton` awaits `viewModel.message()`, whose success pushes the chat through the `navigationDestination(item:)`
  `[lily/Features/People/Views/UserProfileView.swift:messageButton]`;
  Try again spawns `Task { await viewModel.load() }` `[lily/Features/People/Views/UserProfileView.swift:loadFailed]`.
- Navigation values: `UserProfileDestination` from `PersonRow`, `EventGroupRef` from `SharedGroupRow`,
  `TournamentDestination` from `SharedTournamentRow` (every stack root registers all three through `.groupDestinations`)
  `[lily/Features/People/Views/PersonRow.swift:body]`, `[lily/Features/People/Views/SharedGroupRow.swift:body]`,
  `[lily/Features/People/Views/SharedHistoryRows.swift:SharedTournamentRow]`.
- No `ErrorCenter`, `.errorPopup`, logging, `.refreshable` or store mutation; the `#Preview` builds
  `AppDependencies.makeMock()` and `makeUserProfileViewModel(for:)`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/People`); `./scripts/ci.sh ui` (`LilyPeopleTests.testEventDetailListsParticipantsAndOpensAProfile`
  reads the bio, a game together and opens a tournament together).
