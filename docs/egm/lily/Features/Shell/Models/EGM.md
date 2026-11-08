# Shell: Models

Source: `lily/Features/Shell/Models/`

## Overview

The shell's plain data: the tab list, the create intent a keyboard shortcut parks on the navigation model, what Home and
Chats show for a session state, and the pure rule that turns a snapshot of Home's three lists into one screen state. All
types are `nonisolated`, `Equatable`/`Hashable` and `Sendable`; the screen reads these instead of a store's flags.

Files: `lily/Features/Shell/Models/AppTab.swift`, `lily/Features/Shell/Models/CreateIntent.swift`,
`lily/Features/Shell/Models/HomeContent.swift`, `lily/Features/Shell/Models/HomeOverviewState.swift`.

## Interface

- `[AppTab.swift:AppTab]`: `nonisolated enum AppTab: Hashable, CaseIterable, Sendable` with cases `home`, `explore`,
  `chat` in bar order (the profile is no tab since 2026-11-07: the corner button presents it as a sheet,
  `AppNavigation.isProfilePresented`); `static var shown: [AppTab]` = `allCases.filter { $0 != .chat ||
  AppConfig.FeatureFlags.chat }`; `var title: String` maps to `AppBranding.homeTitle`, `.exploreTitle`, `.chatsTitle`.
- `[CreateIntent.swift:CreateIntent]`: `nonisolated enum CreateIntent: Hashable, Sendable` with cases `game`, `group`,
  `tournament`; a marker with no members.
- `[HomeContent.swift:HomeContent]`: `nonisolated enum HomeContent: Equatable, Sendable` with cases `signInPrompt`,
  `overview`; `init(for state: SessionState)` sets `self = state.isSignedIn ? .overview : .signInPrompt`.
- `[HomeOverviewState.swift:HomeListSnapshot]`: `nonisolated struct HomeListSnapshot: Equatable, Sendable` with
  `let isEmpty: Bool`, `let hasAnswered: Bool`, `let loadFailed: Bool`.
- `[HomeOverviewState.swift:HomeSectionState]`: `nonisolated enum HomeSectionState: Equatable, Sendable` with cases
  `loading`, `failed`, `empty`, `content`.
- `[HomeOverviewState.swift:HomeOverviewState]`: `nonisolated enum HomeOverviewState: Equatable, Sendable` with cases
  `loading`, `empty(loadFailed: Bool)`, `sections(groups: HomeSectionState?, tournaments: HomeSectionState?, games:
  HomeSectionState)`; `static func resolve(events: HomeListSnapshot, groups: HomeListSnapshot?, tournaments:
  HomeListSnapshot?) -> HomeOverviewState`; private helpers `sectionState(of:)` and `tournamentsSectionState(of:)`.

## Invariants

- `[AppTab.swift:AppTab.shown]`: keeps `allCases` order and drops `.chat` only when `AppConfig.FeatureFlags.chat` is
  off; the file's comment ties the ⌘1–⌘3 shortcuts to this list so the numbers never skip (`ShellCommands` numbers by
  `index + 1`, so Release, with chat off, is ⌘1 Home, ⌘2 Explore).
- `[HomeContent.swift:HomeContent.init]`: only `SessionState.isSignedIn` yields `.overview`; a guest or a signed-out
  state yields `.signInPrompt`.
- `[HomeOverviewState.swift:HomeOverviewState.resolve]`: a `nil` list (a feature flag off) is dropped by `compactMap`
  and never waited for. The rule is ordered: (1) if any present list is non-empty, or `tournaments?.loadFailed == true`,
  return `.sections`; (2) else if any present list has `!hasAnswered`, return `.loading`; (3) else return
  `.empty(loadFailed: events.loadFailed || groups?.loadFailed == true)`. So the screen never says "nothing" while a
  list it waits for is still out.
- `[HomeOverviewState.swift:HomeOverviewState.sectionState]`: `.content` if non-empty, else `.loading` if not answered,
  else `.failed` or `.empty` by `loadFailed`.
- `[HomeOverviewState.swift:HomeOverviewState.tournamentsSectionState]`: `.content` if non-empty, `.failed` if the load
  failed, otherwise `nil` (the section is hidden; it is never `.loading` or `.empty`).
- `[AppTab.swift:AppTab]`, `[CreateIntent.swift:CreateIntent]`, `[HomeContent.swift:HomeContent]`,
  `[HomeOverviewState.swift:HomeOverviewState]`: `nonisolated` value types, so they are `Sendable` and testable off the
  main actor.

## Side Effects

- None. `[HomeOverviewState.swift:HomeOverviewState.resolve]` and `[HomeContent.swift:HomeContent.init]` are pure
  functions of their inputs; `[AppTab.swift:AppTab.shown]` only reads a compile-time feature flag.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suites are `lilyTests/Shell/HomeContentTests.swift`
  and `lilyTests/Shell/HomeOverviewStateTests.swift`).
