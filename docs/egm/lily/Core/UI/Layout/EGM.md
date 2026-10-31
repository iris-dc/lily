# Layout

Source: `lily/Core/UI/Layout/`

## Overview

How every adaptive view decides and measures. `LayoutMode` (compact, regular, wide) is resolved from the window's
horizontal size class and width and published through the environment by `layoutModeProvider()` together with
`windowWidth` and `windowHeight`; `UsableWidth` is the width a row may use once the window's safe-area regions (the
iPad sidebar) are subtracted; `FlowArrangement` is the pure row-packing arithmetic behind `FlowLayout` (in
[Components](../Components/EGM.md)); the grids (`AdaptiveCardGrid`, `TileGrid`), the readable column and the form-sheet
sizing shape the regular widths; and the tab bar's hide-and-show across a `NavigationStack` is owned by `TabBarHiding`
(`animatesTabBar(depth:)`, `hidesTabBarOnCompact()`). Two UIKit seams: `onArrival` (a screen's navigation transition
has finished) and `KeyboardDismissal` (end editing and wait for the keyboard to be gone). Nothing here looks at the
device; the mode is the only switch. Widths, counts and durations come from `DesignTokens` in `lily/Config`.

## Interface

- `nonisolated enum LayoutMode: Equatable, Sendable { case compact, regular, wide }`
  [`lily/Core/UI/Layout/LayoutMode.swift:LayoutMode`]: `static func resolve(sizeClass: UserInterfaceSizeClass?, width: CGFloat) -> LayoutMode`;
  `var isRegular: Bool` (`self != .compact`). `@Entry var layoutMode: LayoutMode = .compact` on `EnvironmentValues`
  [`lily/Core/UI/Layout/LayoutMode.swift:EnvironmentValues.layoutMode`]. `func layoutModeProvider() -> some View`
  [`lily/Core/UI/Layout/LayoutMode.swift:View.layoutModeProvider`]: measures the root with `onGeometryChange` and
  publishes `\.layoutMode`, `\.windowWidth` and `\.windowHeight` to every descendant (`DesignTokens.Layout.wideMinWidth`).
- `nonisolated enum UsableWidth` [`lily/Core/UI/Layout/UsableWidth.swift:UsableWidth`]:
  `static func of(leading: CGFloat, trailing: CGFloat, frameInWindow: CGRect, windowWidth: CGFloat?) -> CGFloat`, the
  frame's width less the parts that overlap the window's leading and trailing safe-area regions. `@Entry var windowWidth: CGFloat?`
  and `@Entry var windowHeight: CGFloat?` [`lily/Core/UI/Layout/UsableWidth.swift:EnvironmentValues.windowWidth`,
  `EnvironmentValues.windowHeight`], `nil` until `layoutModeProvider()` sets them.
- `nonisolated enum FlowArrangement` [`lily/Core/UI/Layout/FlowArrangement.swift:FlowArrangement`] (CoreGraphics only):
  `struct Row: Equatable, Sendable { var indices: [Int]; var width: CGFloat; var height: CGFloat }`;
  `static func proposedWidth(ideal: CGFloat, lineWidth: CGFloat) -> CGFloat?`;
  `static func rows(for sizes: [CGSize], in width: CGFloat, spacing: CGFloat) -> [Row]`;
  `static func height(of rows: [Row], rowSpacing: CGFloat) -> CGFloat`.
- `struct AdaptiveCardGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable`
  [`lily/Core/UI/Layout/AdaptiveCardGrid.swift:AdaptiveCardGrid`]: `data`, `singleColumn = false`,
  `content: (Data.Element) -> Content`; a `LazyVGrid` whose columns come from
  `nonisolated static func columns(for sizeClass: UserInterfaceSizeClass?) -> [GridItem]`
  (`DesignTokens.Layout.cardMinWidth`, `cardMaxWidth`, `DesignTokens.Spacing.md`).
- `struct TileGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable`
  [`lily/Core/UI/Layout/TileGrid.swift:TileGrid`]: `data`, `content`; `nonisolated static var columns: [GridItem]` (one
  `.adaptive(minimum: DesignTokens.Layout.tileMinWidth)`); `nonisolated static func shown(of data: Data) -> [Data.Element]`;
  horizontal padding `DesignTokens.Layout.screenMargin`.
- `func readableColumn(maxWidth: CGFloat = DesignTokens.Layout.readableWidth) -> some View` and
  `func inReadableColumn() -> some View` (`padding(.horizontal, DesignTokens.Layout.detailMargin)` then `readableColumn()`)
  [`lily/Core/UI/Layout/ReadableColumn.swift:View.readableColumn`, `View.inReadableColumn`].
- `func lilyFormSheet() -> some View` [`lily/Core/UI/Layout/FormSheet.swift:View.lilyFormSheet`]: `presentationSizing(.form)`.
- `func lilyHoverable() -> some View` [`lily/Core/UI/Layout/HoverEffects.swift:View.lilyHoverable`]: `hoverEffect(.highlight)`.
- `func selectedRowBackground(_ isSelected: Bool) -> some View`
  [`lily/Core/UI/Layout/SelectedRowBackground.swift:View.selectedRowBackground`]: an accent wash
  (`Color.lilyAccent.opacity(DesignTokens.Opacity.selectedRow)`, radius `DesignTokens.Radius.md`, bleeding
  `DesignTokens.Spacing.sm` horizontally) behind a selected row.
- `@Observable final class TabBarHiding` [`lily/Core/UI/Layout/TabBarHiding.swift:TabBarHiding`]:
  `func hide(_ token: AnyHashable, at depth: Int)`, `func prune(above depth: Int)`, `func hides(at depth: Int) -> Bool`.
  `@Entry var tabBarHiding: TabBarHiding?` and `@Entry var navigationDepth = 0`
  [`lily/Core/UI/Layout/TabBarHiding.swift:EnvironmentValues.tabBarHiding`, `EnvironmentValues.navigationDepth`].
  `func animatesTabBar(depth: Int) -> some View` [`lily/Core/UI/Layout/TabBarHiding.swift:View.animatesTabBar`]: owns
  one `TabBarHiding` for a `NavigationStack`, publishes it and `depth`, and animates `toolbarVisibility(_, for: .tabBar)`
  (`DesignTokens.Duration.normal`).
- `func hidesTabBarOnCompact() -> some View` [`lily/Core/UI/Layout/HidesTabBarOnCompact.swift:View.hidesTabBarOnCompact`]:
  a screen registers with the stack's `TabBarHiding` under a per-view `UUID` token at its `navigationDepth`; with no
  `TabBarHiding` in the environment it sets `toolbarVisibility` itself.
- `func onArrival(perform arrived: @escaping () -> Void, onDeparture departed: @escaping () -> Void) -> some View`
  [`lily/Core/UI/Layout/ArrivalReader.swift:View.onArrival`]: `arrived` once the hosting controller's navigation
  transition has completed (at once when there is none), `departed` when the view leaves its window; backed by a
  private `UIViewRepresentable`.
- `extension Binding { func isPresent<Wrapped>() -> Binding<Bool> where Value == Wrapped? }`
  [`lily/Core/UI/Layout/Binding+IsPresent.swift:Binding.isPresent`];
  `confirmationDialog(item: Binding<Item?>, title: (Item) -> String, actions:)`,
  `confirmationDialog(item:title:actions:message:)` and `alert(item:title:actions:message:)`
  [`lily/Core/UI/Layout/Binding+IsPresent.swift:View.confirmationDialog(item:title:actions:)`,
  `View.confirmationDialog(item:title:actions:message:)`, `View.alert(item:title:actions:message:)`]: the item-driven
  forms of SwiftUI's presenters.
- `enum KeyboardDismissal` [`lily/Core/UI/Layout/KeyboardDismissal.swift:KeyboardDismissal`], main-actor:
  `static func dismissAndWait(atMost timeout: Duration) async`, ends editing on the key window and, if a hide began,
  waits for `keyboardDidHideNotification` bounded by `Deadline.within` (`lily/Core/Concurrency`).

## Invariants

- `LayoutMode.resolve`: `guard sizeClass == .regular else { return .compact }`, then
  `width >= DesignTokens.Layout.wideMinWidth ? .wide : .regular`; a compact or `nil` size class is `.compact` whatever
  the width [`lily/Core/UI/Layout/LayoutMode.swift:LayoutMode.resolve`]. `isRegular` is `self != .compact`, so `.wide`
  counts as regular [`lily/Core/UI/Layout/LayoutMode.swift:LayoutMode.isRegular`].
- `layoutModeProvider()`: width is `onGeometryChange(for: CGFloat.self, of: \.size.width)`; height is
  `size.height + safeAreaInsets.top + safeAreaInsets.bottom`; published as `windowWidth = width > 0 ? width : nil`,
  `windowHeight = height > 0 ? height : nil`, `layoutMode = LayoutMode.resolve(sizeClass:width:)`
  [`lily/Core/UI/Layout/LayoutMode.swift:LayoutModeProvider`].
- `UsableWidth.of`: `max(width - coveredLeading - coveredTrailing, 0)`, where `coveredLeading` is the frame's overlap
  with `[0, leading]`, `coveredTrailing` its overlap with `[windowWidth - trailing, windowWidth]` when the window width is
  known and `min(trailing, width)` otherwise; `overlap = max(min(frame.maxX, end) - max(frame.minX, start), 0)`
  [`lily/Core/UI/Layout/UsableWidth.swift:UsableWidth.of`].
- `FlowArrangement.rows`: a new row starts only when `!row.indices.isEmpty && row.width + spacing + size.width > width`,
  so a row's first item is never wrapped (an item wider than the line gets its own row); spacing is added only between
  items; `row.height = max(row.height, size.height)`; the trailing row is appended only if non-empty; an infinite width
  yields one row, empty input `[]` [`lily/Core/UI/Layout/FlowArrangement.swift:FlowArrangement.rows`]. `proposedWidth`
  returns `nil` unless `lineWidth.isFinite && ideal > lineWidth`
  [`lily/Core/UI/Layout/FlowArrangement.swift:FlowArrangement.proposedWidth`]; `height` is the row heights plus
  `rowSpacing * max(rows.count - 1, 0)` [`lily/Core/UI/Layout/FlowArrangement.swift:FlowArrangement.height`].
- `AdaptiveCardGrid.columns(for:)`: one `.flexible()` top-aligned column unless `sizeClass == .regular`, then one
  `.adaptive(minimum: cardMinWidth, maximum: cardMaxWidth)`; `singleColumn` forces the compact branch
  (`singleColumn ? .compact : sizeClass`) [`lily/Core/UI/Layout/AdaptiveCardGrid.swift:AdaptiveCardGrid.columns(for:)`].
  `TileGrid.shown(of:)` draws only `data.prefix(DesignTokens.Layout.regularTileCount)`
  [`lily/Core/UI/Layout/TileGrid.swift:TileGrid.shown(of:)`].
- `readableColumn`: `frame(maxWidth: maxWidth).frame(maxWidth: .infinity)`, capped and centred
  [`lily/Core/UI/Layout/ReadableColumn.swift:View.readableColumn`]. `lilyFormSheet` is exactly
  `presentationSizing(.form)`, no detents [`lily/Core/UI/Layout/FormSheet.swift:View.lilyFormSheet`].
- Tab bar: `TabBarHiding.hide` registers once per token (`if depths[token] == nil`), a later call with the same token
  and another depth is ignored; `prune(above:)` keeps entries with `value <= depth`; `hides(at:)` is
  `depths.values.contains { $0 <= depth }`, hidden if the top screen or any screen under it registered
  [`lily/Core/UI/Layout/TabBarHiding.swift:TabBarHiding.hide`, `TabBarHiding.prune`, `TabBarHiding.hides`].
  `AnimatesTabBar` sets `isHidden = hiding.hides(at: depth) && !layoutMode.isRegular` inside
  `withAnimation(.easeInOut(duration: DesignTokens.Duration.normal))` on `onChange(..., initial: true)`, so the bar
  never hides on a regular or wide layout, and prunes on `onChange(of: depth)`; each stack owns its own `@State`
  `TabBarHiding()` [`lily/Core/UI/Layout/TabBarHiding.swift:AnimatesTabBar.body`]. `HidesTabBarOnCompact` with a
  `TabBarHiding` present only registers (`onAppear { hiding.hide(token, at: depth) }`); without one it sets
  `toolbarVisibility(layoutMode.isRegular ? .automatic : .hidden, for: .tabBar)`
  [`lily/Core/UI/Layout/HidesTabBarOnCompact.swift:HidesTabBarOnCompact.body`].
- `onArrival` is not once-only: `didMoveToWindow` runs each time the view joins or leaves a window. `window == nil`
  calls `departed`; otherwise `arrived` is queued on `hostingController?.transitionCoordinator?.animate(alongsideTransition: nil, completion:)`
  and called at once when there is no hosting controller, no coordinator, or the coordinator declines; the hosting
  controller is the first `UIViewController` up the `UIResponder.next` chain; the reader view has
  `isUserInteractionEnabled = false` [`lily/Core/UI/Layout/ArrivalReader.swift:ArrivalReader.ReaderView.didMoveToWindow`].
- `Binding.isPresent`: `get` is `wrappedValue != nil`; `set` writes `nil` only on `false`, `true` is a no-op
  [`lily/Core/UI/Layout/Binding+IsPresent.swift:Binding.isPresent`]. The `item:` presenters pass
  `isPresented: item.isPresent()`, `presenting: item.wrappedValue` and title `item.wrappedValue.map(title) ?? ""`; the
  dialogs add `titleVisibility: .visible` [`lily/Core/UI/Layout/Binding+IsPresent.swift:View.confirmationDialog(item:title:actions:)`].
- `KeyboardDismissal.dismissAndWait`: the `keyboardWillHideNotification` observer is added before
  `keyWindow?.endEditing(true)` and removed right after; `guard seen.isGoing else { return }`, so it waits only when a
  hide began during `endEditing`; then it awaits the first `keyboardDidHideNotification` under
  `try? await Deadline.within(timeout)` (a timeout is swallowed); the key window is the first `isKeyWindow` across
  `UIApplication.shared.connectedScenes`, and with none `endEditing` is not called
  [`lily/Core/UI/Layout/KeyboardDismissal.swift:KeyboardDismissal.dismissAndWait`].
- Isolation: `LayoutMode`, `UsableWidth`, `FlowArrangement`, `AdaptiveCardGrid.columns(for:)`, `TileGrid.columns` and
  `TileGrid.shown(of:)` are `nonisolated` (testable without a view); the views, modifiers, `TabBarHiding` and
  `KeyboardDismissal` are main-actor isolated.

## Side Effects

- Environment writes: `layoutModeProvider()` sets `\.layoutMode`, `\.windowWidth`, `\.windowHeight`
  [`lily/Core/UI/Layout/LayoutMode.swift:LayoutModeProvider.body`]; `animatesTabBar(depth:)` sets `\.tabBarHiding`,
  `\.navigationDepth` and `toolbarVisibility(_, for: .tabBar)` [`lily/Core/UI/Layout/TabBarHiding.swift:AnimatesTabBar.body`];
  `hidesTabBarOnCompact()` sets `toolbarVisibility` when no `TabBarHiding` is present
  [`lily/Core/UI/Layout/HidesTabBarOnCompact.swift:HidesTabBarOnCompact.body`].
- Observable and view state: `TabBarHiding.hide` inserts into `depths`, `prune` reassigns it, and
  `hidesTabBarOnCompact()` mutates the shared instance from `onAppear` [`lily/Core/UI/Layout/TabBarHiding.swift:TabBarHiding`];
  `@State` `width`/`height` change from `onGeometryChange`, `isHidden` inside `withAnimation`.
- UIKit: `KeyboardDismissal` enumerates `UIApplication.shared.connectedScenes`, calls `endEditing(true)` (resigns the
  first responder), adds and removes a `NotificationCenter` observer (its block runs `MainActor.assumeIsolated`) and
  awaits `center.notifications(named: keyboardDidHideNotification)`
  [`lily/Core/UI/Layout/KeyboardDismissal.swift:KeyboardDismissal.dismissAndWait`]. `ArrivalReader` creates a `UIView`,
  walks the responder chain, calls `transitionCoordinator?.animate(alongsideTransition:completion:)` with `[weak self]`,
  and reassigns the closures in `updateUIView` [`lily/Core/UI/Layout/ArrivalReader.swift:ArrivalReader`].
- `Binding.isPresent()`'s setter writes `nil` to the source binding when set to `false`
  [`lily/Core/UI/Layout/Binding+IsPresent.swift:Binding.isPresent`].
- No logging, no I/O, no network, no `Task`s or `DispatchQueue` hops; the only suspension is `KeyboardDismissal`'s wait.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the suites are `lilyTests/UI/LayoutModeTests.swift`,
  `UsableWidthTests.swift`, `FlowArrangementTests.swift`, `TabBarHidingTests.swift`, `BindingIsPresentTests.swift` and
  `RegularWidthLayoutTests.swift`). Compact, regular and wide rendering is checked by screenshot on iPhone and iPad
  simulators per `AGENTS.md` (evidence in `docs/notes/ipad.md` and `docs/notes/shell-and-navigation.md`).
