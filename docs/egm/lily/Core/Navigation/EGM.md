# Navigation

Source: `lily/Core/Navigation/`

## Overview

The shell's navigation state in one observable object: the selected tab, the `NavigationPath` of the Home and Chats
stacks, on a regular width the conversation the Chats split view shows, and whether the profile sheet is up
(2026-11-07, the relocation contract). Anything that opens a screen from elsewhere
(a group detail's "Open chat", an accepted invite, a tapped notification, a keyboard shortcut) selects a tab and goes
through this type, so the tab bar and the stack roots are the only views that bind to it. It observes the session so a
sign-out resets every per-user path.

## Interface

- `@Observable final class AppNavigation: SessionObserver` (main-actor). State: `var selectedTab: AppTab = .explore`,
  `var homePath = NavigationPath()`, `var chatPath = NavigationPath()`, `var usesSplitChats = false`,
  `var selectedConversation: ConversationSelection?`, `var pendingCreate: CreateIntent?`,
  `var isProfilePresented = false` (the profile sheet `MainTabView` presents; the corner button on every tab root sets
  it, 2026-11-07), `private(set) var shellGeneration = 0` [`lily/Core/Navigation/AppNavigation.swift:AppNavigation`].
- Opening: `openInHome(_ destination: some Hashable)`, `openInChat(_ destination: some Hashable)`,
  `open(group: SportGroup)`, `open(event: SportEvent)` (2026-11-11, a created game's landing),
  `open(tournament: TournamentDestination)`, `open(chat group: SportGroup)`,
  `openInbox()`, `openFromNotification(_ destination: some Hashable)`, `requestCreate(_ intent: CreateIntent)`
  [`AppNavigation.swift:AppNavigation`].
- Resetting: `popHomeToRoot()`, `popChatToRoot()` [`AppNavigation.swift:AppNavigation.popHomeToRoot()`].
- Launch: `static func startTab(for state: SessionState) -> AppTab`, `static func startTab(signedIn: Bool) -> AppTab`
  [`AppNavigation.swift:AppNavigation.startTab(signedIn:)`].
- Session callbacks: `sessionDidRestore()`, `sessionDidEnd()` [`AppNavigation.swift:AppNavigation.sessionDidEnd()`].

## Invariants

- `openInHome` sets `selectedTab = .home` then appends to `homePath`; `openInChat` sets `.chat` then appends to
  `chatPath`; `open(group:)`, `open(event:)` and `open(tournament:)` go through `openInHome`
  [`AppNavigation.swift:AppNavigation.openInHome(_:)`, `AppNavigation.swift:AppNavigation.openInChat(_:)`].
- `open(chat:)`: with `AppConfig.FeatureFlags.chat` off it opens the group on Home instead; with `usesSplitChats` it
  selects `.room(id: group.id)` in the split view's detail; otherwise it pushes `ChatDestination(group:)` on Chats
  [`AppNavigation.swift:AppNavigation.open(chat:)`].
- `openInbox()`: `.inbox` selected on a regular width, `InboxDestination()` pushed otherwise
  [`AppNavigation.swift:AppNavigation.openInbox()`].
- A split-view selection always pops the Chats stack to its root first, so a screen pushed over the previous
  conversation cannot hide the new one [`AppNavigation.swift:AppNavigation.select(_:)`].
- `openFromNotification` lands on Chats when `AppConfig.FeatureFlags.chat` is on, on Home otherwise
  [`AppNavigation.swift:AppNavigation.openFromNotification(_:)`].
- `requestCreate` selects Explore and parks the intent in `pendingCreate` for Explore to consume
  [`AppNavigation.swift:AppNavigation.requestCreate(_:)`].
- `startTab(signedIn:)` is `.home` for a signed-in user and `.explore` for everyone else; `startTab(for:)` reads
  `state.isSignedIn`; `sessionDidRestore()` selects the signed-in start tab
  [`AppNavigation.swift:AppNavigation.startTab(signedIn:)`, `AppNavigation.swift:AppNavigation.sessionDidRestore()`].
- `sessionDidEnd()` increments `shellGeneration` (the root keys the shell on it), selects Explore, clears
  `selectedConversation`, `pendingCreate` and `isProfilePresented`, and empties both paths
  [`AppNavigation.swift:AppNavigation.sessionDidEnd()`].
- `isProfilePresented` is only state: the model presents nothing itself. The shell also clears it the moment the terms
  sheet must present (the profile sheet yields; the mount and the yield are `MainTabView`'s,
  `docs/egm/lily/Features/Shell/Views/EGM.md`) [`AppNavigation.swift:AppNavigation`].
- `usesSplitChats` is set by the shell from the window's layout; the model never reads a size class
  [`AppNavigation.swift:AppNavigation.usesSplitChats`].

## Side Effects

- Mutates its own observable state only; no I/O, no logging. Reads `AppConfig.FeatureFlags.chat`
  [`AppNavigation.swift:AppNavigation`].

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites live under `lilyTests/Navigation`)
