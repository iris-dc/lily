# People Views

Source: `lily/Features/People/Views/`

## Overview

Three views: `PersonRow` (a roster or participant row that links to a person's profile unless it is the caller),
`SharedGroupRow` (a "Groups in common" row linking to the group's detail) and `UserProfileView` (the profile screen:
avatar, name, Message when allowed, the shared groups). Loading and writes belong to
[ViewModels](../ViewModels/EGM.md); the views log nothing, report nothing and mutate no store.

## Interface

- `PersonRow<Badge: View>(userID: String, displayName: String, isSelf: Bool, identifier: String, badge: () -> Badge)`
  `[lily/Features/People/Views/PersonRow.swift:PersonRow]`: pushes `UserProfileDestination(userId:displayName:)`
  (context `.standalone`); the identifier is caller-supplied; the name comes from `AppBranding.People.name(_:isSelf:)`.
- `SharedGroupRow(group: GroupSummary)` `[lily/Features/People/Views/SharedGroupRow.swift:SharedGroupRow]`:
  `GroupRowContent(name:visibility:caption:hasUnread: false)` in a `NavigationLink(value: group.ref)`; identifier
  `AccessibilityIdentifiers.groupRow(group.id)` (`group-row-<id>`).
- `UserProfileView(viewModel: UserProfileViewModel)` `[lily/Features/People/Views/UserProfileView.swift:UserProfileView]`:
  `ContentScreen` with a `ScrollView` in a `readableColumn()`, inline title `viewModel.displayName`; private `header`,
  `messageButton` (a `BusyButton` with `lilyProminentButton()`, identifier `AccessibilityIdentifiers.profileMessage`,
  `profile-message`), `sharedGroups`, `sharedGroupsContent`, `rows(_:)` (container identifier
  `AccessibilityIdentifiers.profileSharedGroups`, `profile-shared-groups`), `loadFailed`, `note(_:)`.
- Copy: `AppBranding.People.message`, `sharedGroupsTitle`, `noSharedGroups`, `loadFailedTitle`,
  `AppBranding.Groups.tryAgain` `[lily/Features/People/Views/UserProfileView.swift:UserProfileView]`.

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
- State to content: `.loading` a spinner; `.failed` the failed state with Try again; `.loaded` with empty
  `sharedGroups` the "no shared groups" note; otherwise the rows in the order received (no filtering or sorting), each
  followed by `AvatarRowDivider()` `[lily/Features/People/Views/UserProfileView.swift:sharedGroupsContent]`,
  `[lily/Features/People/Views/UserProfileView.swift:rows]`.
- The rows container is `.accessibilityElement(children: .contain)` before `profileSharedGroups`, so each row keeps
  its `group-row-<id>` `[lily/Features/People/Views/UserProfileView.swift:rows]`.
- No `LayoutMode` references in the three files.

## Side Effects

- `.task { await viewModel.load() }` `[lily/Features/People/Views/UserProfileView.swift:body]`; the Message
  `BusyButton` awaits `viewModel.message()` `[lily/Features/People/Views/UserProfileView.swift:messageButton]`;
  Try again spawns `Task { await viewModel.load() }` `[lily/Features/People/Views/UserProfileView.swift:loadFailed]`.
- Navigation values: `UserProfileDestination` from `PersonRow`, `EventGroupRef` from `SharedGroupRow`
  `[lily/Features/People/Views/PersonRow.swift:body]`, `[lily/Features/People/Views/SharedGroupRow.swift:body]`.
- No `ErrorCenter`, `.errorPopup`, logging, `.refreshable` or store mutation; the `#Preview` builds
  `AppDependencies.makeMock()` and `makeUserProfileViewModel(for:)`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/People`).
