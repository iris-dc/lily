# Shell: Views

Source: `lily/Features/Shell/Views/`

## Overview

The signed-in and guest shell: a `TabView` of Home, Explore and Chats (flag-gated), kept by the root for the
app's lifetime and empty while the landing covers it; the profile as a sheet, presented once from the shell root over
the corner control every tab root carries (`ProfileCornerButton`; the Profile tab was removed 2026-11-07, the
relocation contract); the Home root with its guest prompt or the three-section overview;
the Explore tab wrapping the shared `EventListView` with the group and tournament carousels; and the Chats tab choosing
between a stack and the iPad split view. Lists are read from `dependencies.lists` (`ShellLists`), navigation from
`dependencies.navigation` (`AppNavigation`), and the screens shown inside (`ProfileView`, `ChatsView`, `ChatsSplitView`,
`EventListView`, `EventDetailView`, `GroupCarousel`, `TournamentCarousel`) belong to other features.

Files: `lily/Features/Shell/Views/MainTabView.swift`, `lily/Features/Shell/Views/ProfileCornerButton.swift`,
`lily/Features/Shell/Views/HomeTab.swift`,
`lily/Features/Shell/Views/HomeView.swift`, `lily/Features/Shell/Views/HomeOverview.swift`,
`lily/Features/Shell/Views/ExploreTab.swift`, `lily/Features/Shell/Views/ChatTab.swift`,
`lily/Features/Shell/Views/GuestSignInPrompt.swift`.

## Interface

- `[MainTabView.swift:MainTabView]`: `dependencies: AppDependencies`, `showsContent: Bool`; reads `\.layoutMode`.
  `TabView(selection: $navigation.selectedTab)` of `Tab(value: .home)` (`HomeTab`), `.explore` (`ExploreTab`) and `.chat`
  (`ChatTab`, its label `chatTabLabel(count:selected:)`: the unread count drawn into the glyph image by the
  `@State`-held `TabBadgeRenderer`, because the bar ignores `UITabBarAppearance.badgePositionAdjustment` (2026-11-12
  probe) and honours only the label's title and `UIImage`; the composite is `.alwaysOriginal`, so the glyph colour
  follows `navigation.selectedTab` — `UIColor(Color.lilyAccent)` selected, `DesignTokens.TabBar.unselectedGlyphColor`
  otherwise — and at zero the plain template `tabLabel` returns, see `docs/notes/design-and-ui.md`); every tab's
  tree carries `.id(language)` where
  `language = dependencies.language.language`. The profile sheet mounts on the `TabView` (2026-11-07):
  `.sheet(isPresented: $navigation.isProfilePresented) { ProfileView(dependencies:language:) }` — above each tab's
  `.id(language)` (a language pick rebuilds the tabs while the sheet re-renders in place) and inside the root's
  `.id(shellGeneration)`. `unreadChats =
  dependencies.unreadCenter.count + (dependencies.inbox.hasUnread ? 1 : 0)`, exposed as
  `.accessibilityValue(Text(AppBranding.Chats.unreadChats(unreadChats)), isEnabled: unreadChats > 0)`. Labels pair
  `AppBranding.homeTitle`/`exploreTitle`/`chatsTitle` with `DesignTokens.Symbols.home`/`explore`/
  `chat` through `tabLabel(for:symbol:)`, which reads the title from `AppTab.title`, a `UIImage.SymbolConfiguration(weight:
  DesignTokens.TabBar.symbolWeight)`; `.tabBarMinimizeBehavior(.onScrollDown)`.
- `[ProfileCornerButton.swift:ProfileCornerButton]` (2026-11-07): `ToolbarContent` over `dependencies`; one
  `.topBarLeading` item under `.sharedBackgroundVisibility(.hidden)` whose button sets
  `navigation.isProfilePresented = true`. The label is an `AvatarCircle` at `DesignTokens.Layout.profileCornerSize`:
  the signed-in caller's initials from `dependencies.profile.displayName` (the snapshot answers at first frame; the
  button itself triggers no request), the `DesignTokens.Symbols.profile` glyph for a guest or while no name is known —
  the profile header's own fallback. Accessibility label `AppBranding.profileTitle`, identifier
  `AccessibilityIdentifiers.profileCorner`. Applied at exactly four stack roots, nowhere else: `HomeView`,
  `EventListView` (Explore's root), `ChatsView` and `ChatsSplitView`'s sidebar column (the relocation contract §3).
  The rendering was settled by the 2026-11-08 design round: the hidden capsule and the 36 pt circle kept as rendered
  (`docs/notes/design-and-ui.md` 2026-11-08; shots under
  `reviews/2026-11-07-profile-lifecycle-brainstorm/slice4-shots/design-round/`). An owner correction the same day
  backs the circle out of the hidden capsule's 10 pt content inset (`.padding(.leading,
  -DesignTokens.Layout.profileCornerCapsuleInset)`), so it takes the capsule's own leading edge — flush with the
  large titles' 16 pt margin on the iPhone, the system capsule's own edge on the iPad (`design-and-ui.md` 2026-11-08,
  owner corrections; shots under `reviews/2026-11-07-profile-lifecycle-brainstorm/corrections1-shots/`).
- `[HomeTab.swift:HomeTab]`: `NavigationStack(path: $navigation.homePath) { HomeView(dependencies:) }` with
  `.animatesTabBar(depth: navigation.homePath.count)`.
- `[HomeView.swift:HomeView]`: `dependencies`; `events = dependencies.lists.homeEvents`, `tournaments =
  dependencies.lists.homeTournaments`; `content = HomeContent(for: dependencies.sessionController.state)`; a private
  `LoadKey: Hashable { userID: String?; eventsVersion: Int; tournamentsVersion: Int }`. Body: `ContentScreen` showing
  `GuestSignInPrompt(symbolName: DesignTokens.Symbols.home, message: AppBranding.Home.guestMessage, dependencies:)` or
  `HomeOverview(groups: dependencies.myGroups, events:, tournaments:, dependencies:)`; `.navigationTitle(AppBranding.homeTitle)`;
  `.toolbar { ProfileCornerButton(dependencies:) }`;
  `.groupDestinations(dependencies:onTournamentChange: tournaments.replace)`; `.navigationDestination(for:
  SportEvent.self)` pushing `EventDetailView(viewModel: dependencies.makeEventDetailViewModel(for:onChange:
  events.replace), dependencies:)`; `.task(id: loadKey) { await loadIfStale() }`.
- `[HomeOverview.swift:HomeOverview]`: `groups: MyGroupsStore`, `events: EventListViewModel`, `tournaments:
  TournamentListViewModel`, `dependencies`; reads `\.horizontalSizeClass`; `state: HomeOverviewState` from
  `HomeOverviewState.resolve`. Renders `ProgressView()`, or a refreshable scroll of `EmptyStateView` (`emptyState`
  with `AppBranding.Home.emptyTitle`/`emptyMessage`/`exploreAction`, `loadFailedState` with
  `AppBranding.Home.loadFailedTitle` and `AppBranding.Events.loadFailedMessage`), or the sections: `SectionTitle`
  headings `AppBranding.Home.groupsSection`, `AppBranding.Tournaments.mineSection`, `AppBranding.Home.gamesSection`;
  `GroupTileGrid(groups:distance:)` or `GroupRowList(groups:)`, `TournamentCardList(tournaments:distance:)`,
  `EventCardList(events:distance:)`; notes `AppBranding.Home.groupsLoadFailed`/`noGroups`/`gamesLoadFailed`/`noGames`
  and `AppBranding.Tournaments.mineLoadFailed`.
- `[ExploreTab.swift:ExploreTab]`: `dependencies`; `discover = dependencies.lists.discover`, `tournaments =
  dependencies.lists.exploreTournaments`; body is `EventListView(listTitle:, viewModel: dependencies.lists.exploreEvents,
  dependencies:, refreshHeader: refreshCarousels, header: carousels)` with `listTitle = AppBranding.Events.eventsSection`
  when a carousel shows, else `nil`; `carousels()` is `GroupCarousel(viewModel: discover)` and
  `TournamentCarousel(viewModel: tournaments)` behind their flags.
- `[ChatTab.swift:ChatTab]`: `dependencies`; reads `\.layoutMode`; `ChatsSplitView(dependencies:)` when
  `showsSplitView`, else `NavigationStack(path: $navigation.chatPath) { ChatsView(dependencies:) }` with
  `.animatesTabBar(depth: navigation.chatPath.count)`.
- `[GuestSignInPrompt.swift:GuestSignInPrompt]`: `symbolName: String`, `message: String`, `dependencies`; `@State
  isSignInPresented`; `EmptyStateView(symbolName:, title: AppBranding.guestProfileTitle, message:, actionTitle:
  AppBranding.signInAction)` under `.readableColumn()`, presenting `SignInSheet(session:errorCenter:)`.

## Invariants

- `[MainTabView.swift:MainTabView.body]`: the Chats tab exists only `if AppConfig.FeatureFlags.chat`; while
  `!showsContent` every tab's content is `Color.clear.toolbarVisibility(.hidden, for: .tabBar)`, so no screen loads or
  asks for the position behind the landing and the bar stays built but hidden; `.animation(nil, value: showsContent)`
  keeps the bar from sliding in.
- `[MainTabView.swift:MainTabView.body]`: `.onChange(of: layoutMode.isRegular, initial: true)` writes
  `dependencies.navigation.usesSplitChats`; the navigation model never reads size classes itself.
- `[MainTabView.swift:MainTabView.body]`: the terms-over-sheet yield was removed 2026-11-08 with the terms gate
  (owner decision: the app never prompts to accept terms); the profile sheet is the shell's root-level sheet. A
  session end tears it down twice over: `sessionDidEnd()` clears the flag and the `shellGeneration` bump rebuilds the
  view.
- `[HomeView.swift:HomeView.loadIfStale]`: `await dependencies.sessionController.restore()` first, then `guard
  !Task.isCancelled, content == .overview else { return }`: a guest asks for nothing and nothing is requested before the
  pool confirmed the cached user. The three loads (`events.loadIfStale()`, `myGroups.loadIfStale()` behind
  `AppConfig.FeatureFlags.groups`, `tournaments.loadIfStale()` behind `AppConfig.FeatureFlags.tournaments`) run as
  `async let` children; the position is asked for after them. The `.task(id: loadKey)` restarts on a new user id or a
  bump of `dependencies.eventChanges.version` / `dependencies.tournamentChanges.version`.
- `[HomeOverview.swift:HomeOverview.state]`: the groups snapshot is passed only when `AppConfig.FeatureFlags.groups`,
  the tournaments snapshot only when `AppConfig.FeatureFlags.tournaments`; `hasAnswered` is `!events.isInitialLoad`,
  `groups.hasLoaded || groups.loadFailed`, `!tournaments.isInitialLoad`.
- `[HomeOverview.swift:HomeOverview.sections]`: with groups off only `gamesContent` is drawn, without a heading; the
  tournaments section appears only inside the groups branch and only when its state is non-`nil`.
- `[HomeOverview.swift:HomeOverview.groupsContent]`: `.content where sizeClass == .regular` draws the tile grid, any
  other `.content` the row list.
- `[ExploreTab.swift:ExploreTab.showsGroups]`: `AppConfig.FeatureFlags.groups && !discover.groups.isEmpty`;
  `showsTournaments` likewise with `tournaments.visibleTournaments`.
- `[ChatTab.swift:ChatTab.showsSplitView]`: `layoutMode.isRegular && HomeContent(for:
  dependencies.sessionController.state) == .overview`; a guest gets the full-width stack on every width.
- `[HomeView.swift:HomeView.body]`: the one `SportEvent` navigation destination on the Home stack is declared here.

## Side Effects

- Loads: `[HomeView.swift:HomeView.loadIfStale]` calls `sessionController.restore()`, `events.loadIfStale()`,
  `myGroups.loadIfStale()`, `tournaments.loadIfStale()`, then `events.loadUserLocation()` and (flag)
  `tournaments.loadUserLocation()` (location permission and fix). `[ExploreTab.swift:ExploreTab.body]` runs
  `.task(id: dependencies.groupChanges.version)` → `discover.loadIfStaleNearTheUser()` and `.task(id:
  dependencies.tournamentChanges.version)` → `tournaments.loadIfStaleNearTheUser()`; `refreshCarousels` calls
  `discover.search()` and `tournaments.load()`.
- `[HomeOverview.swift:HomeOverview.refreshableScroll]`: pull-to-refresh awaits `groups.reload()` (flag),
  `tournaments.load()` (flag) and `events.load()`.
- Navigation writes: `[HomeOverview.swift:HomeOverview.groupsContent]` `dependencies.navigation.open(group:)`;
  `[HomeOverview.swift:HomeOverview.emptyState]` `dependencies.navigation.selectedTab = .explore`;
  `[MainTabView.swift:MainTabView.body]` binds `selectedTab` and `isProfilePresented` (presenting `ProfileView` as the
  profile sheet, which mounts its own `.errorPopup`), sets `usesSplitChats`; `[ProfileCornerButton.swift:ProfileCornerButton]` sets `isProfilePresented = true`;
  `[HomeTab.swift:HomeTab]` and `[ChatTab.swift:ChatTab]` bind `homePath` and `chatPath`.
- `[MainTabView.swift:MainTabView.tabLabel(for:symbol:)]`: builds `UIImage(systemName:withConfiguration:)` glyphs (UIKit); `chatTabLabel(count:selected:)` asks the `@State` `TabBadgeRenderer` for the badged composite, rendered once per count and colour and cached (2026-11-12).
- `[GuestSignInPrompt.swift:GuestSignInPrompt]`: presents `SignInSheet`, which mounts its own `.errorPopup`.
- `[HomeView.swift:HomeView.body]`: `tournaments.replace` and `events.replace` are handed to the destinations as change
  callbacks that mutate the Home lists.
- No logging, disk or `UserDefaults` access is made directly by these views.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the state rules these views draw are pinned in
  `lilyTests/Shell`; the screens themselves are exercised by the UI tests, `./scripts/ci.sh ui` and
  `./scripts/ci.sh ui-ipad`).
