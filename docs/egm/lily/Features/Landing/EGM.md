# Landing

Source: `lily/Features/Landing/`

## Overview

The first screen of iskra for a signed-out visitor: a vertical, page-snapping intro of framed miniature screens over the
aurora, with "Explore events" (continue as a guest) and "Sign in" pinned under every slide. The feature has no direct
source files; it is split into plain data (`Models`), one observable view model (`ViewModels`) and the SwiftUI views
(`Views`). The slides a build shows follow `AppConfig.FeatureFlags` (groups and chat, tournaments); the events and the
tournament bracket the miniatures draw are `IntroFixtures`, never a live answer, so the first screen does not change
under the reader. Sign-in is presented as `SignInSheet` from `lily/Features/SignIn`; the guest entry goes
through `SessionController.continueAsGuest()`.

## Subdirectories & Boundaries

- Models: [./Models/EGM.md](./Models/EGM.md) - `IntroSlide` (cases `events`, `join`, `groups`, `tournaments`;
  `shown(groups:tournaments:)` filters by the feature flags; `keepsBottom`), `IntroContent` (`events`, derived
  `joinEvent`, `tournament`), `TapPulseCurve` (pure phase and frame arithmetic for the Join ring, `intro` on design
  tokens) and `IntroFixtures` (the Kreuzberg Kickers room, `events(now:)`, `tournament(now:)`). All `nonisolated`,
  `Sendable`, no side effects.
- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `LandingViewModel` (`@Observable`): `slides`,
  `introContent` (the samples), `slideShown(_:)` (clears the swipe hint on a real change),
  `enterApp()` (`session.continueAsGuest()`), `presentSignIn()`.
- Views: [./Views/EGM.md](./Views/EGM.md) - `LandingView` (aurora, `IntroPager`, `IntroPageIndicator`, the two
  buttons, the `SignInSheet`), `IntroPager` (paging only below accessibility type sizes, `AccessibilityIdentifiers.introPager`),
  `IntroSlideView` (compact stacked or regular side-by-side, `AccessibilityIdentifiers.introSlide(_:)`),
  `IntroScreenFrame` (the cropped, faded, non-interactive phone frame), the four miniature screens in `IntroScreens.swift`
  with the private clock-driven `TapPulse`, and `LandingHeadline`.
