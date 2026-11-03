# Landing: ViewModels

Source: `lily/Features/Landing/ViewModels/`

## Overview

One observable view model drives the landing screen: the slides this build shows, the events the miniature screens draw
(the fixtures, dated from launch; never a live answer, which changed the first screen under the reader), the tournament
whose bracket the last slide draws, the slide on screen and the swipe hint, and the two ways into the app (guest,
sign-in sheet). It is main-actor isolated by the app target's default and depends on `Logging` plus the
`SessionController`; it makes no request.

Files: `lily/Features/Landing/ViewModels/LandingViewModel.swift`.

## Interface

- `[LandingViewModel.swift:LandingViewModel]`: `@Observable final class LandingViewModel`. Stored state: `let slides =
  IntroSlide.shown()`; `let sampleEvents: [SportEvent]`;
  `let sampleTournament: TournamentDetail`; `private(set) var currentSlide: IntroSlide = .first`;
  `private(set) var showsSwipeHint = true`; `var isSignInPresented = false`.
- `[LandingViewModel.swift:LandingViewModel.init]`: `init(session: SessionController, logger: any Logging)`; fills `sampleEvents` from `IntroFixtures.events(now: .now)` and
  `sampleTournament` from `IntroFixtures.tournament(now: .now)`, so the samples are dated from launch.
- `[LandingViewModel.swift:LandingViewModel.introContent]`: `var introContent: IntroContent` =
  `IntroContent(events: sampleEvents, tournament: sampleTournament)`.
- `[LandingViewModel.swift:LandingViewModel.slideShown]`: `func slideShown(_ slide: IntroSlide?)`, the pager's report
  of the slide at rest.
- `[LandingViewModel.swift:LandingViewModel.enterApp]`: `func enterApp()` calls `session.continueAsGuest()`;
  `func presentSignIn()` sets `isSignInPresented = true`.

## Invariants

- `[LandingViewModel.swift:LandingViewModel.introContent]`: the events are always `sampleEvents`
  (`AppConfig.Events.introSampleEventCount` of the mock feed) and the tournament always `sampleTournament`; nothing the
  landing shows changes while it is on screen.
- `[LandingViewModel.swift:LandingViewModel.slideShown]`: `guard let slide, slide != currentSlide else { return }`: a
  `nil` report (swipe in flight) or the same slide again (a rebound) changes nothing; `showsSwipeHint` goes `false`
  only on a real slide change and never comes back.
- `[LandingViewModel.swift:LandingViewModel.slides]`: fixed at construction from the build's feature flags
  (`IntroSlide.shown()` defaults); the list does not change while the landing is on screen.
- `[LandingViewModel.swift:LandingViewModel]`: `currentSlide` and `showsSwipeHint` are `private(set)`;
  views may only toggle `isSignInPresented` directly.

## Side Effects

- No network: the landing makes no request (the live preview of upcoming events was removed 2026-11-03, since its
  arrival changed the first slide under the reader).
- Logging: `[LandingViewModel.swift:LandingViewModel.slideShown]` logs `.ui` debug `"Intro slide <rawValue> shown"`.
- Session: `[LandingViewModel.swift:LandingViewModel.enterApp]` calls `session.continueAsGuest()`, which moves the
  session state and so the root from the landing to the shell.
- No tasks are spawned here, nothing is written to disk or `UserDefaults`.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the matching suite is
  `lilyTests/Landing/LandingViewModelTests.swift`).
