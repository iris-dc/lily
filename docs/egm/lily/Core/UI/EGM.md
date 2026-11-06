# UI

Source: `lily/Core/UI/`

## Overview

The app's shared SwiftUI layer, with no files of its own: five folders that give every feature screen its look and its
adaptive behaviour. `Components` holds the views and view modifiers (the `ContentScreen` scaffold and its aurora, the
button, chip and field modifiers, cards, rows, tiles, the error popup, the draft sheet, the growing text field);
`Layout` decides and measures (`LayoutMode`, `UsableWidth`, `FlowArrangement`, the grids, the tab bar's hiding);
`Effects` is the pure arithmetic behind the aurora and the launch (`AuroraGeometry`, `AuroraPalette`, `AuroraReveal`,
`FilmGrain`, `LaunchAnimations`); `Theme` maps semantics to fonts, glass and the aurora's colors (`LilyTheme`); and
`Interfaces` holds the one protocol a shared view needs from a feature model (`DraftSubmitting`). Visual constants
live in `DesignTokens` (`lily/Config`), copy in `AppBranding`; the generated `Color.lily*` asset symbols are
main-actor isolated, so the arithmetic that must run anywhere (`Effects`, `Layout`'s enums, `LilyTheme.DateStyles`) is
`nonisolated` and asset-free, and the views are main-actor.

## Subdirectories & Boundaries

- Components: [./Components/EGM.md](./Components/EGM.md) - The reusable views and modifiers: `ContentScreen`,
  `AuroraBackground` (a wall-clock `TimelineView` over a `MeshGradient`, frozen under `\.motion == .reduced` or
  `-freeze-aurora`), `FilmGrainOverlay`, `lilyProminentButton` / `lilyGlassButton` / `lilyIconButton` /
  `lilyTextButton` / `lilyToolbarTextButton` (text actions in ink, never the accent), `lilyChip`,
  `ChoiceChip`, `lilyField`, `GlassCard`, `FlowLayout`, titles, `ChevronLink`, `ValidationHint`, `AvatarCircle`
  (accent, secondary or sport tint; the sport mark a maroon-to-accent `sportFill` with a white glyph),
  `ConversationRow`, `TileCarousel`,
  `EntriesBar` over `CapacityMeter`,
  `EmptyStateView`, `ListSegment`, `FilterDropdownButton`, `ErrorPopupView` and `errorPopup(_:)`
  (the topmost mount draws, auto- and swipe-dismiss), `DraftSheet`, `GrowingTextView` with `PlaceholderTextView`.
- Layout: [./Layout/EGM.md](./Layout/EGM.md) - `LayoutMode` (compact, regular, wide) resolved from the size class and
  width and published with `windowWidth` / `windowHeight` by `layoutModeProvider()`; `MotionPreference` (full, reduced)
  resolved once from Reduce Motion and published as `\.motion` by `motionProvider()`; `UsableWidth.of`; the pure
  `FlowArrangement` row packing; `AdaptiveCardGrid`, `TileGrid`, `readableColumn`, `lilyFormSheet`; `TabBarHiding` with
  `animatesTabBar(depth:)` and `hidesTabBarOnCompact()` (the bar never hides on a regular layout); `onArrival`,
  `Binding.isPresent` and the item-driven dialogs; `KeyboardDismissal.dismissAndWait(atMost:)`.
- Effects: [./Effects/EGM.md](./Effects/EGM.md) - `nonisolated` arithmetic: `AuroraGeometry` (16 mesh points and cell
  intensities, phases reduced modulo their period in `Double` before `Float`), `AuroraRole` / `AuroraPalette` (the 4x4
  role layout), `AuroraReveal` (one process-wide smoothstep fade from a lazy `start`), `FilmGrain` (seeded xorshift64
  gray tiles); plus the main-actor `LaunchAnimations`, which calls `UIView.setAnimationsEnabled(false)` at launch and
  re-enables one run-loop turn after the root's first frame, with a timed fallback.
- Theme: [./Theme/EGM.md](./Theme/EGM.md) - `LilyTheme`: the SF Pro `Fonts`, the `nonisolated` `DateStyles.dateTime`
  (a `static var` re-reading `AppLocale.locale`), `selectionGlass(isSelected:)` / `selectionLabelColor(isSelected:)`,
  and `auroraColors(intensities:)` mapping `AuroraPalette.roles` to `Color.lily*` with the opacity clamped to one.
- Interfaces: [./Interfaces/EGM.md](./Interfaces/EGM.md) - `DraftSubmitting` (`AnyObject`, `Observable`; `issues`,
  `isSubmitting`, `canSubmit`, `isDone`, `prepare()`, `submit()`, `issue(for:)`), the contract `DraftSheet` drives;
  `prepare()` is both a requirement and an empty default so a conformer's own runs.
