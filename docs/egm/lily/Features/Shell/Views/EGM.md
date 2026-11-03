# Shell: Views

Source: `lily/Features/Shell/Views/`

## Overview

The signed-in and guest shell: a `TabView` of Home, Explore, Chats (flag-gated) and Profile, kept by the root for the
app's lifetime and empty while the landing covers it; the Home root with its guest prompt or the three-section overview;
the Explore tab wrapping the shared `EventListView` with the group and tournament carousels; and the Chats tab choosing
between a stack and the iPad split view. Lists are read from `dependencies.lists` (`ShellLists`), navigation from
`dependencies.navigation` (`AppNavigation`), and the screens shown inside (`ProfileView`, `ChatsView`, `ChatsSplitView`,
`EventListView`, `EventDetailView`, `GroupCarousel`, `TournamentCarousel`) belong to other features.

Files: `lily/Features/Shell/Views/MainTabView.swift`, `lily/Features/Shell/Views/HomeTab.swift`,
`lily/Features/Shell/Views/HomeView.swift`, `lily/Features/Shell/Views/HomeOverview.swift`,
`lily/Features/Shell/Views/ExploreTab.swift`, `lily/Features/Shell/Views/ChatTab.swift`,
`lily/Features/Shell/Views/GuestSignInPrompt.swift`.

## Interface

- `[MainTabView.swift:MainTabView]`: `dependencies: AppDependencies`, `showsContent: Bool`; reads `\.layoutMode`.
  `TabView(selection: $navigation.selectedTab)` of `Tab(value: .home)` (`HomeTab`), `.explore` (`ExploreTab`), `.chat`
  (`ChatTab`, with `.badge(unreadChats)`) and `.profile` (`ProfileView(dependencies:language:)`); Home, Explore and
  Chats trees carry `.id(language)` where `language = dependencies.language.language`. `unreadChats =
  dependencies.unreadCenter.count + (dependencies.inbox.hasUnread ? 1 : 0)`, exposed as
  `.accessibilityValue(Text(AppBranding.Chats.unreadChats(unreadChats)), isEnabled: unreadChats > 0)`. Labels pair
  `AppBranding.homeTitle`/`exploreTitle`/`chatsTitle`/`profileTitle` with `DesignTokens.Symbols.home`/`explore`/
  `chat`/`profile` through `tabLabel(for:symbol:)`, which reads the title from `AppTab.title`, a `UIImage.SymbolConfiguration(weight:
  DesignTokens.TabBar.symbolWeight)`; `.tabBarMinimizeBehavior(.onScrollDown)`.
- `[HomeTab.swift:HomeTab]`: `NavigationStack(path: $navigation.homePath) { HomeView(dependencies:) }` with
  `.animatesTabBar(depth: navigation.homePath.count)`.
- `[HomeView.swift:HomeView]`: `dependencies`; `events = dependencies.lists.homeEvents`, `tournaments =
  dependencies.lists.homeTournaments`; `content = HomeContent(for: dependencies.sessionController.state)`; a private
  `LoadKey: Hashable { userID: String?; eventsVersion: Int; tournamentsVersion: Int }`. Body: `ContentScreen` showing
  `GuestSignInPrompt(symbolName: DesignTokens.Symbols.home, message: AppBranding.Home.guestMessage, dependencies:)` or
  `HomeOverview(groups: dependencies.myGroups, events:, tournaments:, dependencies:)`; `.navigationTitle(AppBranding.homeTitle)`;
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
  `[MainTabView.swift:MainTabView.body]` binds `selectedTab` and sets `usesSplitChats`; `[HomeTab.swift:HomeTab]` and
  `[ChatTab.swift:ChatTab]` bind `homePath` and `chatPath`.
- `[MainTabView.swift:MainTabView.tabLabel(for:symbol:)]`: builds `UIImage(systemName:withConfiguration:)` glyphs (UIKit).
- `[GuestSignInPrompt.swift:GuestSignInPrompt]`: presents `SignInSheet`, which mounts its own `.errorPopup`.
- `[HomeView.swift:HomeView.body]`: `tournaments.replace` and `events.replace` are handed to the destinations as change
  callbacks that mutate the Home lists.
- No logging, disk or `UserDefaults` access is made directly by these views.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the state rules these views draw are pinned in
  `lilyTests/Shell`; the screens themselves are exercised by the UI tests, `./scripts/ci.sh ui` and
  `./scripts/ci.sh ui-ipad`).
