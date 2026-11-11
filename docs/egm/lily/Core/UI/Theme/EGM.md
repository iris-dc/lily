# Theme

Source: `lily/Core/UI/Theme/`

## Overview

`LilyTheme`: semantic styling that is not a plain color asset. Colors live in `Assets.xcassets` as the generated
`Color.lily*` symbols (main-actor isolated); here are the SF Pro font set (`Fonts`), the one date-and-time style
(`DateStyles`), the selected look of toggling controls (`selectionGlass`, `selectionLabelColor`) and the mapping from
the aurora's cell roles and per-cell intensities (see [Effects](../Effects/EGM.md)) to the mesh colors
(`auroraColors`). Sizes, fractions and opacities come from `DesignTokens` in `lily/Config`, never from literals here.

## Interface

- `enum LilyTheme` [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme`]: main-actor isolated namespace (the app target's
  default isolation); its members read the generated asset colors, which are main-actor only.
- `enum LilyTheme.Fonts` [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.Fonts`], every member a `static var` or
  `static func` returning `Font`:
  - `headline` = `headline(scale: 1)`; `headline(scale: CGFloat)` =
    `.system(size: DesignTokens.Typography.headlineSize * scale, weight: .bold)` (the landing headline, shrunk so a
    line fits in one).
  - `screenTitle` (`.largeTitle`, bold), `cardTitle` (`.title3`, semibold), `sectionTitle` (`.title2`, bold),
    `button` (`.body`, semibold), `floatingAction` (`.title2`, bold; the floating create button's glyph), `itemTitle`
    (`.body`, semibold; the name line of a row, tile or card over a caption), `caption`
    (`.footnote`, medium). (`glyph`, the `.title3` symbol in a `GlassGlyph`, removed 2026-11-06 with that view.)
  - `sportGlyph(size: CGFloat)` [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.Fonts.sportGlyph(size:)`] =
    `.system(size: size * DesignTokens.Layout.sportGlyphFraction, weight: .semibold)`, a sport's glyph inside its
    filled mark of `size` points (`AvatarCircle` with the `.sport` tint, `EventTypeChip`).
  - `avatarInitials(size: CGFloat)` [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.Fonts.avatarInitials(size:)`] =
    `.system(size: size * DesignTokens.Layout.avatarInitialsFraction, weight: .bold)`, the initials inside an avatar
    circle of `size` points.
- `nonisolated enum LilyTheme.DateStyles` [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.DateStyles`]:
  `static var dateTime: Date.FormatStyle` = `dateTime(locale: AppLocale.locale)`;
  `static func dateTime(locale: Locale) -> Date.FormatStyle` =
  `Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale)` ("15 Jan 2027 at 18:30"), the one style of
  the facts cards and match rows; `static var date: Date.FormatStyle` = `Date.FormatStyle(date: .abbreviated, time:
  .omitted, locale: AppLocale.locale)` ("15 Jan 2027"), the day alone for what is past or far (a profile's shared
  history captions); `static var time: Date.FormatStyle` = `Date.FormatStyle(date: .omitted, time: .shortened,
  locale: AppLocale.locale)` ("18:30"), the time alone for a finish on the start's own day (the facts card's
  "Until …" line, 2026-11-11).
- `static var sportGradient: LinearGradient` [`lily/Core/UI/Components/SportFill.swift:LilyTheme.sportGradient`]:
  `.lilyAccentDeep` at the bottom-leading corner to `.lilyAccent` at the top-trailing one, the fill of every sport mark
  (`View.sportFill(in:)`, see [Components](../Components/EGM.md)); declared beside its one consumer, in `Components`.
- `static func selectionGlass(isSelected: Bool) -> Glass` [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.selectionGlass(isSelected:)`]:
  `.regular.tint(Color.lilyAccent)` when selected, `.regular` otherwise (map pins, `ChoiceChip`).
- `static func selectionLabelColor(isSelected: Bool) -> Color` [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.selectionLabelColor(isSelected:)`]:
  `.white` when selected, `.lilyInk` otherwise.
- `static func auroraColors(intensities: [Double]) -> [Color]` [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.auroraColors(intensities:)`]:
  `zip(AuroraPalette.roles, intensities)` mapped by role: `.surface` to `.lilySurface`; `.mass(density)` to
  `.lilyAccentDeep` at `AuroraPalette.massOpacity(density)`; `.core` to `.lilyAuroraCore` at
  `DesignTokens.Aurora.coreOpacity`; `.ember` to `.lilySecondary` at `DesignTokens.Aurora.emberOpacity`; each opacity
  scaled by the cell's intensity. The core has its own colorset so retuning the interactive accent leaves the background
  alone.

## Invariants

- Opacity clamp: a role's opacity times its cell intensity is `min(1, opacity * intensity)`, so a ripple crest over a
  dense cell cannot exceed one [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.scaled`]. `.surface` cells ignore the
  intensity and return plain `.lilySurface` [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.auroraColor`].
- `auroraColors` returns `min(AuroraPalette.roles.count, intensities.count)` colors (`zip`); there is no guard on
  `intensities.count`, the caller passes the 16 values of `AuroraGeometry.cellIntensities(at:)`
  [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.auroraColors(intensities:)`].
- `DateStyles.dateTime`, `date` and `time` are computed `static var`s, never `static let`s: a `let` would freeze
  the first language, the `var` re-reads `AppLocale.locale` on every access
  [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.DateStyles.dateTime`].
- `DateStyles` is `nonisolated`, usable from non-main-actor formatting code; `LilyTheme`, `Fonts`, the selection
  helpers and `auroraColors` are main-actor isolated because they touch the generated asset colors
  [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.DateStyles`].
- Every font is `.system` (SF Pro, the design language's one family); sizes are text styles or `DesignTokens` values,
  no literals [`lily/Core/UI/Theme/LilyTheme.swift:LilyTheme.Fonts`].

## Side Effects

- None: every member is a pure function of its arguments, `DesignTokens` and `AppLocale.locale`.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; `lilyTests/UI/DateStylesTests.swift` pins `DateStyles`).
  Fonts, the selection glass and the aurora colors are checked as rendered, by screenshot on a simulator per
  `AGENTS.md`.
