# Groups Views

Source: `lily/Features/Groups/Views/`

## Overview

Twenty-seven SwiftUI files: the Discover screen with its card list, carousel and tiles; the group detail (header,
access-driven action row and toolbar menu, Events, Tournaments and Members segments, its sheets and one confirmation
dialog); the edit draft form and sheet with its standalone visibility and permission section contents
(extracted 2026-11-10 for the creation wizard's pages; creating walks the wizard since slice 3, 2026-11-11, seeded
from the detail's create affordances); the invite and report sheets; roster, group and conversation
rows; and `groupDestinations`, the `View` modifier that registers every typed navigation destination a stack needs
for groups. Views own or receive the view models of [ViewModels](../ViewModels/EGM.md) through `AppDependencies` and
call them from `task`, `refreshable`, `onChange` and button actions; role gating comes from `GroupAccess` and
`GroupDetailSection.available` in [Models](../Models/EGM.md), and every destructive action waits for a
`GroupConfirmation` dialog in `GroupDetailView`.

## Interface

- `GroupDetailView(viewModel: GroupDetailViewModel, dependencies: AppDependencies)`: owns `@State` `viewModel`,
  `events: EventListViewModel` (scope `.group(id:)`), `tournaments: TournamentListViewModel`, `members:
  MembersViewModel?`, `section: GroupDetailSection`, `presentedSheet: DetailSheet?` (`invite`, `edit`, `createEvent`,
  `createTournament`, `signIn`, `report`; `isWizard` marks the two create cases), `wizardModel:
  AppCreationWizardModel?` (made once per presentation in `GroupDetailView+Create.swift`'s `presentWizard`, owned
  above both presenters), `confirmation: GroupConfirmation?`; reads `@Environment(\.dismiss)` and `\.layoutMode`;
  stamps `AccessibilityIdentifiers.groupSection` [`lily/Features/Groups/Views/GroupDetailView.swift`:`GroupDetailView`].
- `GroupActionRow(viewModel:, onOpenChat:, onInvite:, onCreateEvent:, onSignIn:)` (identifiers `groupJoin`,
  `groupOpenChat`, `groupInvite`, `groupCreateEvent`) [`lily/Features/Groups/Views/GroupActionRow.swift`:`GroupActionRow`];
  `GroupDetailMenu(viewModel:, onInvite:, onCreateTournament:, onEdit:, onLeave:, onReport:, onDelete:)`
  (identifiers `groupLeave`, `groupReport`, `groupMore`) [`lily/Features/Groups/Views/GroupDetailMenu.swift`:`GroupDetailMenu`];
  `GroupHeader(group:, distance:)` [`lily/Features/Groups/Views/GroupHeader.swift`:`GroupHeader`];
  `GroupEventsSegment(viewModel: EventListViewModel)` [`lily/Features/Groups/Views/GroupEventsSegment.swift`:`GroupEventsSegment`].
- `GroupLoaderView(viewModel: GroupLoaderViewModel, dependencies:)` switching on `GroupLoaderViewModel.State`
  [`lily/Features/Groups/Views/GroupLoaderView.swift`:`GroupLoaderView`].
- `DiscoverGroupsView(dependencies:)` owning a `DiscoverGroupsViewModel` from `makeDiscoverGroupsViewModel()`, binding
  `$viewModel.query` (searchable) and `$viewModel.typeFilter` (identifier `groupsTypeFilter`)
  [`lily/Features/Groups/Views/DiscoverGroupsView.swift`:`DiscoverGroupsView`]; `DiscoverGroupList(viewModel:)`
  [`lily/Features/Groups/Views/DiscoverGroupList.swift`:`DiscoverGroupList`]; `GroupCarousel(viewModel:)` (identifiers
  `groupsSeeAll`, `groupCarousel`) and `GroupTileGrid(groups:, distance:)` with `static tile(for:distance:fillsWidth:)`
  [`lily/Features/Groups/Views/GroupCarousel.swift`:`GroupTileGrid`]; `GroupTile(group:, distance:, fillsWidth:)`
  [`lily/Features/Groups/Views/GroupTile.swift`:`GroupTile`]; `GroupCard(group:, distance:)`
  [`lily/Features/Groups/Views/GroupCard.swift`:`GroupCard`]; `GroupBadge(ref: EventGroupRef, capsWidth:)`
  [`lily/Features/Groups/Views/GroupBadge.swift`:`GroupBadge`]; `HostedInLine(group: EventGroupRef)`
  [`lily/Features/Groups/Views/HostedInLine.swift`:`HostedInLine`], a `ChevronLink` (`lily/Core/UI/Components`) when
  the group is linkable, the same label in `.secondary` otherwise.
- `GroupDraftSheet<Model: GroupDraftEditing>(viewModel:, title:, submitTitle:, errorCenter:)`
  over the shared `DraftSheet` (identifiers `createGroupCancel`, `createGroupSubmit`)
  [`lily/Features/Groups/Views/GroupDraftSheet.swift`:`GroupDraftSheet`]; `GroupDraftForm(draft: Binding<GroupDraft>,
  issues:)` (identifiers `createGroupName`, `createGroupDescription`, `createGroupLocationName`,
  `createGroupLocationDetail` — the optional detail line, 2026-11-12 — `createGroupPickOnMap`; the description row wears the shared `OptionalMarker`, 2026-11-11 — the where section's
  footer already says "Optional for a private group.")
  [`lily/Features/Groups/Views/GroupDraftForm.swift`:`GroupDraftForm`], and
  `GroupPermissionToggles(membersCanCreateEvents:, membersCanInvite:)`, the two member-permission toggles
  [`lily/Features/Groups/Views/GroupPermissionToggles.swift`:`GroupPermissionToggles`] — the permissions section
  content, standalone since 2026-11-10; `EditGroupSheet(viewModel:, errorCenter:)`
  [`lily/Features/Groups/Views/EditGroupSheet.swift`:`EditGroupSheet`] (creating walks the wizard; `CreateGroupSheet`
  deleted with slice 3, 2026-11-11; the visibility section, `GroupVisibilityChoice`, `allowsVisibilityChoice` and the
  `createGroupVisibility` identifier deleted 2026-11-11 — the visibility is fixed once created and the wizard's
  visibility page owns the create pick as cards, so the form never offers it).
- `InvitePeopleSheet(viewModel:, errorCenter:)` (identifier `inviteSearch`; Done is `lilyToolbarTextButton()`) and
  `InviteCandidateRow(candidate:, isSending:, onInvite:)` (identifiers `inviteCandidate(id)`, `inviteSend(id)`)
  [`lily/Features/Groups/Views/InvitePeopleSheet.swift`:`InvitePeopleSheet`]
  [`lily/Features/Groups/Views/InviteCandidateRow.swift`:`InviteCandidateRow`].
- `MembersList(viewModel: MembersViewModel, confirm: (GroupConfirmation) -> Void)` (identifier `membersList`) and
  `MemberRow(member:, isSelf:)` (identifier `memberRow(id)`) [`lily/Features/Groups/Views/MembersList.swift`:`MembersList`]
  [`lily/Features/Groups/Views/MemberRow.swift`:`MemberRow`].
- `ReportSheet(viewModel: ReportViewModel, errorCenter:)` (identifiers `reportComment`, `reportDone`, `reportSubmit`;
  Done and Cancel are `lilyToolbarTextButton()`) [`lily/Features/Groups/Views/ReportSheet.swift`:`ReportSheet`].
- `GroupRow(group:, hasUnread:)`, `GroupRowContent(name:, visibility:, caption:, hasUnread:, isPerson:,
  avatarSymbol:, markTint: AvatarCircle.Tint = .secondary)` [`lily/Features/Groups/Views/GroupRow.swift`:`GroupRow`,
  `GroupRowContent`] (`markTint` is the non-person mark's tint: `.sport` for a game's type, 2026-11-06);
  `GroupRowList<RowMenu: View>(groups:,
  unread: UnreadCenter?, selectedID:, rowMenu:, onOpen:)` (identifier `groupRow(id)` per row) and its `RowMenu ==
  EmptyView` convenience `init(groups:, unread:, onOpen:)` [`lily/Features/Groups/Views/GroupRowList.swift`:`GroupRowList`].
- `View.groupDestinations(dependencies:, onTournamentChange: (@MainActor (Tournament) -> Void)? = nil)`, applying
  the private `GroupDestinations` modifier that registers `navigationDestination(for:)` `SportGroup`,
  `GroupInfoDestination`, `EventGroupRef`, `ChatDestination`, `DiscoverGroupsDestination`, `UserProfileDestination`,
  `TournamentDestination`, `DiscoverTournamentsDestination`
  [`lily/Features/Groups/Views/GroupDestinations.swift`:`groupDestinations`].

## Invariants

- `GroupActionRow` switches exhaustively on `access`: `.member`/`.conversation`/`.room` show the member actions, in
  which Open chat needs `showsOpenChat`, Invite `canInvite(in:)` and Create game `canCreateEvents(in:)`; `.canJoin`
  shows a `BusyButton` (join) and `.guest` a sign-in button, both `lilyProminentButton()`; `.inviteOnly` is a caption
  only; `.full` a `BusyButton` reading "Group is full" in the prominent style; the join, sign-in and full buttons
  share `groupJoin`
  [`lily/Features/Groups/Views/GroupActionRow.swift`:`GroupActionRow`].
- `GroupDetailMenu` items are gated: Invite by `canInvite`, Create tournament by `AppConfig.FeatureFlags.tournaments
  && canCreateEvents`, Edit by `canEdit`, Leave (destructive) by `canLeave`, Report by `viewModel.canReport`, Delete
  (destructive) by `canDelete` [`lily/Features/Groups/Views/GroupDetailMenu.swift`:`GroupDetailMenu`]; the toolbar
  item is added only when `viewModel.showsMenu` [`lily/Features/Groups/Views/GroupDetailView.swift`:`GroupDetailView`].
- `GroupDetailView` roots in `ContentScreen { ScrollView }` with `.refreshable`, `detailMargin` padding and
  `readableColumn()`; `sections = GroupDetailSection.available(for:in:)`, the segmented picker shows only for more than
  one section, and a selection that disappears falls back to `.events`: the private `shownSection` (`.members` only
  with a members model, `.tournaments` only when `sections` offers it, else `.events`) drives both `segment` and the
  pull-to-refresh `refresh()`, so the two cannot drift
  [`lily/Features/Groups/Views/GroupDetailView.swift`:`GroupDetailView`].
- Leave, Delete, Remove and Ban never run directly: they set `confirmation` and run only from the destructive button
  of `.confirmationDialog(item: $confirmation)` titled by `GroupConfirmation.title(groupName:)`; `MembersList` routes
  any action with a `confirmation(for:)` to `confirm(_:)` and shows a context menu only for a non-empty `actions(for:)`
  [`lily/Features/Groups/Views/GroupDetailView.swift`:`GroupDetailView`]
  [`lily/Features/Groups/Views/MembersList.swift`:`MembersList`].
- The members model is rebuilt on every `access` change (`showsRoster ? makeMembersViewModel : nil`); tournament
  loads are gated by `AppConfig.FeatureFlags.tournaments`; the detail dismisses itself when `isGone` turns true
  [`lily/Features/Groups/Views/GroupDetailView.swift`:`GroupDetailView`].
- `GroupDestinations` never opens `GroupDetailView` for a conversation or a room: a `counterpart` goes to
  `UserProfileView`, `isTournamentRoom` to `TournamentDetailView`; a `SportGroup` push is `.standalone`, a
  `GroupInfoDestination` push `.fromChat`; a nil `onTournamentChange` defaults to
  `dependencies.tournamentChanges.recordChange()` [`lily/Features/Groups/Views/GroupDestinations.swift`:`GroupDestinations`].
- `GroupDraftForm` offers no visibility choice (fixed once created; the wizard's visibility page owns the create
  pick, 2026-11-11); the permissions section content is `GroupPermissionToggles`; each section's footer stays in the
  form and shows the first matching `GroupDraft.Issue` (name and description issues under the group section, the
  four location issues under "where", `placeNotChosen` among them since round 5, 2026-11-12; the where section
  hands `draft.placeChosen` and the detail binding to `PlaceFields`); the form uses
  `readableColumn()` [`lily/Features/Groups/Views/GroupDraftForm.swift`:`GroupDraftForm`].
- `DiscoverGroupList` shows a `ProgressView` while `isInitialLoad`, an `EmptyStateView` in a refreshable scroll when
  `nothingMatched`, else an `AdaptiveCardGrid`; `loadMore` fires only when the appearing card is the last and
  `canLoadMore`; `DiscoverGroupsView` roots in `ContentScreen` with an always-shown navigation-drawer search
  [`lily/Features/Groups/Views/DiscoverGroupList.swift`:`DiscoverGroupList`].
- `GroupLoaderView` maps `.loading` to a `ContentScreen { ProgressView }`, `.loaded` to `GroupDetailView(context:
  .standalone)`, `.notFound` and `.failed` to `EmptyStateView`s (the latter with a retry)
  [`lily/Features/Groups/Views/GroupLoaderView.swift`:`GroupLoaderView`].
- Identified containers set `.accessibilityElement(children: .contain)` before their identifier (`InviteCandidateRow`,
  `MembersList`); the Invite button is disabled when `isInvited || isSending` and reads "sent" once invited
  [`lily/Features/Groups/Views/InviteCandidateRow.swift`:`InviteCandidateRow`].
- Sheets are forms: `InvitePeopleSheet` and `ReportSheet` root in `NavigationStack { ContentScreen }` and mount their
  own popup; `InvitePeopleSheet` through `.lilyFormSheet()` and `.errorPopup(errorCenter)`, `ReportSheet` through
  `.lilyFormSheet(errorCenter:lockedWhile: viewModel.isSubmitting)` after detents `.medium`/`.large` (the grabber, the
  dismissal lock while submitting and the popup in one modifier); its Cancel reads `AppBranding.Forms.cancel` and it
  shows only Done once submitted
  [`lily/Features/Groups/Views/ReportSheet.swift`:`ReportSheet`].
- Rows: `GroupRow` draws a person row for a `counterpart`, else a group row with the visibility glyph and
  `avatarSymbol` (in a `markTint` mark; a person's avatar keeps the accent),
  adding "Active today" only when `isActive(on: .now)`; `GroupRowList` attaches a context menu only when
  a `rowMenu` is given; `MemberRow` shows a role chip for owner and admin only; `GroupCard`/`GroupTile` add the joined
  caption only for members; `HostedInLine` links only when `ref.isLinkable`, and the chevron, never a colour, is the
  link's cue
  [`lily/Features/Groups/Views/GroupRow.swift`:`GroupRow`] [`lily/Features/Groups/Views/HostedInLine.swift`:`HostedInLine`].
- No file branches on `LayoutMode`; adaptive layout is delegated to `AdaptiveCardGrid`, `TileCarousel` and `TileGrid`
  [`lily/Features/Groups/Views/GroupCarousel.swift`:`GroupCarousel`].

## Side Effects

- View-model calls: `loadIfStaleNearTheUser()` on Discover's `.task`, `cancel()` on disappear, `loadMore()` when the
  last card appears, `search()` on pull; `recordViewed()`, `events.loadIfStale()` keyed on `eventChanges.version`,
  `refreshFromStore()` keyed on `(groupChanges.version, myGroups.loadVersion)`, `tournaments.loadIfStale()` keyed on
  `tournamentChanges.version`, `loadUserLocation()` for both lists on the detail; `join()` from the action row;
  `leave()`, `delete()`, `members.perform(.remove|.ban, on:)` after confirmation; `loadIfNeeded()`/`load()` on the
  loader; `load()`/`invite(_:)` on the invite sheet; `submit()` on the report sheet
  [`lily/Features/Groups/Views/GroupDetailView.swift`:`GroupDetailView`]
  [`lily/Features/Groups/Views/DiscoverGroupsView.swift`:`DiscoverGroupsView`]; `members.load()` keyed on the model's
  identity, `unban(_:)` and `perform(_:on:)` from the roster menu
  [`lily/Features/Groups/Views/MembersList.swift`:`MembersList`].
- Navigation: `NavigationLink(value:)`/`TileLink(value:)` push a `SportGroup`, "See all" a `DiscoverGroupsDestination`,
  `HostedInLine` an `EventGroupRef`; Open chat calls `dependencies.navigation.open(chat:)`; `GroupDestinations`
  builds the destination view models through `AppDependencies` (`makeGroupDetailViewModel`, `makeGroupLoaderViewModel`,
  `makeChatViewModel`, `makeUserProfileViewModel`, `makeTournamentDetailViewModel`)
  [`lily/Features/Groups/Views/GroupDestinations.swift`:`GroupDestinations`].
- Sheets presented from the detail: `InvitePeopleSheet`, `EditGroupSheet` (`onChange: viewModel.accept`),
  `SignInSheet`, `ReportSheet`, each with `dependencies.errorCenter`, and the creation wizard for the two create
  cases — seeded `CreationSeed(kind:, lockedGroup: group.ref)` with `onCreatedEvent` adding to `events` then
  opening the game's detail through `dependencies.navigation.open(event:)` (the fourth round, 2026-11-11) and
  `onCreatedTournament` adding to `tournaments` then opening the tournament's detail through
  `dependencies.navigation.open(tournament:)` (the merge review, 2026-11-12), a full-screen cover on compact and a `lilyFormSheet()` otherwise, the two
  presenters split over one `presentedSheet` so a width-class change re-hosts the flow, and
  `clearWizardAfterDismiss` booking the close only on a real dismissal
  [`lily/Features/Groups/Views/GroupDetailView+Create.swift`:`GroupDetailView.presentWizard`]; `dismiss()` from the
  sheets' Done/Cancel and when the group is gone
  [`lily/Features/Groups/Views/GroupDetailView.swift`:`GroupDetailView`].
- Bindings written: `viewModel.query` and `typeFilter` on Discover; `draft.*` fields through `GroupDraftForm`;
  `viewModel.query` on the invite sheet; `reason` and `comment` on the report sheet
  [`lily/Features/Groups/Views/GroupDraftForm.swift`:`GroupDraftForm`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the view models these screens drive are covered under
  `lilyTests/Groups`). The rendered screens are exercised by `./scripts/ci.sh ui` (`lilyUITests/LilyGroupsTests`) and
  checked by screenshot on a simulator per `AGENTS.md`.
