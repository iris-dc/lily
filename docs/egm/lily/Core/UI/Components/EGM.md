# Components

Source: `lily/Core/UI/Components/`

## Overview

The reusable SwiftUI pieces every feature screen is built from, 42 files with no subfolders: the screen scaffold and
its aurora (`ContentScreen`, `AuroraBackground`, `FilmGrainOverlay`), the button, chip, picker and field modifiers that give
the app its one look, the cards, titles, rows, avatars and tiles, the list and empty states, the filter dropdowns, the
shared error popup (`errorPopup`), the create-or-edit sheet (`DraftSheet`) and the UIKit-backed growing text field
(`GrowingTextView`). The arithmetic behind the aurora is in [Effects](../Effects/EGM.md), fonts and colors in
[Theme](../Theme/EGM.md), row packing and the layout mode in [Layout](../Layout/EGM.md), and `DraftSheet`'s model
contract in [Interfaces](../Interfaces/EGM.md). Every size, radius, opacity, symbol and string is a `DesignTokens`,
`AppBranding` or `AccessibilityIdentifiers` constant from `lily/Config`; the views are main-actor isolated because they
use the generated `Color.lily*` asset symbols.

## Interface

- Screen and aurora: `ContentScreen<Content: View>(content:)` [`lily/Core/UI/Components/ContentScreen.swift:ContentScreen`]
  draws `AuroraBackground(intensity: DesignTokens.Aurora.contentIntensity)` under `content()`, sized to `\.windowHeight`
  less the top safe-area inset. `AuroraBackground(intensity: Double = 1)`
  [`lily/Core/UI/Components/AuroraBackground.swift:AuroraBackground`]: `Color.lilySurface`, then in a
  `TimelineView(.animation(minimumInterval: DesignTokens.Aurora.frameInterval, paused:))` a `MeshGradient` from
  `AuroraGeometry.points(at:)` and `LilyTheme.auroraColors(intensities: AuroraGeometry.cellIntensities(at:))` plus
  `FilmGrainOverlay(time:)`, `.ignoresSafeArea()`; `@Entry var auroraFrozen: Bool = false`
  [`lily/Core/UI/Components/AuroraBackground.swift:EnvironmentValues.auroraFrozen`], set by the root from
  `-freeze-aurora`. `FilmGrainOverlay(time: TimeInterval)` [`lily/Core/UI/Components/FilmGrainOverlay.swift:FilmGrainOverlay`]
  tiles one of `DesignTokens.Aurora.grainFrameCount` static `CGImage`s from `FilmGrain.makeImage`, chosen by
  `FilmGrain.frameIndex`; `.interpolation(.none)`, `.blendMode(.plusLighter)`, `.allowsHitTesting(false)`.
- Buttons [`lily/Core/UI/Components/ButtonModifiers.swift:View.lilyProminentButton`, `View.lilyGlassButton`,
  `View.lilyIconButton`, `View.lilyGlassIconButton`, `View.lilyFloatingActionButton`, `View.lilyTextButton`,
  `View.lilyToolbarTextButton`, `LilyTextButtonStyle`]:
  `lilyProminentButton(sizing: ButtonSizing = .flexible, controlSize: ControlSize? = .large)` (`.glassProminent`,
  `Color.lilyAccent`); `lilyGlassButton(sizing: ButtonSizing = .flexible, controlSize: ControlSize? = .large, labelColor: Color? = nil)`
  (`.glass`); `lilyIconButton(controlSize: ControlSize = .large)` and `lilyGlassIconButton()` (always `.large`)
  (glass circles); `lilyFloatingActionButton()` = `lilyIconButton(controlSize: .extraLarge)`;
  `lilyTextButton(font: Font = LilyTheme.Fonts.button, color: Color = .lilyInk, minHeight: CGFloat = DesignTokens.Layout.controlHeight)`
  applies `LilyTextButtonStyle(font:color:minHeight:)`, a `ButtonStyle` for text-only actions ("See all", Reset, the
  sign-in form's text actions, the terms' links and Sign out, a poll's footer); `lilyToolbarTextButton()` is
  `.tint(Color.lilyInk)` for a plain text item in an iOS 26 toolbar (Cancel, Done, Send, Edit).
- Pickers [`lily/Core/UI/Components/PickerModifiers.swift:View.lilyMenuPicker`]: `lilyMenuPicker()` is
  `.pickerStyle(.menu).tint(.secondary)`, the one recipe for a menu picker in a form (the Group and Level rows of the
  event form, the tournament form's Group row, the filter panel's Level row; a default-styled `Picker` in a `Form` is a
  menu picker too): the control colours its value and chevron from the tint, which is the accent in every form sheet
  and reads at about 3:1 as small text, so the recipe puts them in `.secondary` while the row's title stays primary and
  the menu's items keep the system look.
  `BusyLabel<Content>(isBusy:, spinnerSize: ControlSize = .regular, content:)` and
  `BusyButton<Label>(isBusy:, action: (() async -> Void)?, label:)`, each with a `Text` convenience and
  `BusyButton.init(_ title:, isBusy:, write: () async -> Bool, onSuccess: () -> Void)`
  [`lily/Core/UI/Components/BusyButton.swift:BusyLabel`, `BusyButton`].
  `DraftSubmitButton(title:, isSubmitting:, isEnabled:, action: () async -> Void)`
  [`lily/Core/UI/Components/DraftSubmitButton.swift:DraftSubmitButton`].
  `ProviderButton(provider: AuthProvider.Kind, isLoading: = false, isDisabled: = false, action:)` and `ProviderGlyph(provider:)`
  [`lily/Core/UI/Components/ProviderButton.swift:ProviderButton`, `ProviderGlyph`] (`AppBranding.signInButtonTitle(for:)`).
- Chips: `lilyChip(_ glass: Glass)` (caption font, `glassEffect(glass, in: .capsule)`) and
  `tappableLabel(minHeight: CGFloat = DesignTokens.Layout.controlHeight)`
  [`lily/Core/UI/Components/ChipModifiers.swift:View.lilyChip`, `View.tappableLabel`];
  `ChoiceChip(title:, systemImage: String? = nil, isSelected:, action:)` [`lily/Core/UI/Components/ChoiceChip.swift:ChoiceChip`]
  (`LilyTheme.selectionGlass(isSelected:).interactive()`, `selectionLabelColor`); `EventTypeChip(type: EventType)`
  [`lily/Core/UI/Components/EventTypeChip.swift:EventTypeChip`]; `VisibilityChip(visibility: GroupVisibility)`
  [`lily/Core/UI/Components/VisibilityChip.swift:VisibilityChip`];
  `EventTypeChips(anyTitle: String? = nil, anyIdentifier: String? = nil, isSelected: (EventType?) -> Bool, onSelect: (EventType?) -> Void, identifier: ((EventType) -> String)? = nil)`
  over `EventType.known` in a `FlowLayout` [`lily/Core/UI/Components/EventTypeChips.swift:EventTypeChips`].
- Layout pieces: `FlowLayout: Layout` (`spacing`, `rowSpacing`, both `DesignTokens.Spacing.sm`)
  [`lily/Core/UI/Components/FlowLayout.swift:FlowLayout`]; `GlassCard<Content>(content:)`
  [`lily/Core/UI/Components/GlassCard.swift:GlassCard`] (`DesignTokens.Spacing.lg` padding, glass rect of
  `DesignTokens.Radius.card`, `.contentShape(.rect)`); `glassTile(fixedWidth: CGFloat, height: CGFloat, fillsWidth: Bool)`
  [`lily/Core/UI/Components/TileCarousel.swift:View.glassTile(fixedWidth:height:fillsWidth:)`];
  `IconColumnLabelStyle` / `.iconColumn` and `TitleThenIconLabelStyle` / `.titleThenIcon`
  [`lily/Core/UI/Components/LabelStyles.swift:IconColumnLabelStyle`, `TitleThenIconLabelStyle`].
- Titles and text: `ScreenTitle(text:, subtitle: String? = nil)` and `ScreenSubtitle(text:)`
  [`lily/Core/UI/Components/ScreenTitle.swift:ScreenTitle`, `ScreenSubtitle`]; `SectionTitle<Trailing>(text:, trailing:)`
  with `init(text:)` for `EmptyView` [`lily/Core/UI/Components/SectionTitle.swift:SectionTitle`];
  `OwnerTitleBlock<Destination: Hashable>(title:, subtitle:, destination: Destination?)`
  [`lily/Core/UI/Components/OwnerTitleBlock.swift:OwnerTitleBlock`] (its link is a `ChevronLink`);
  `ChevronLink<Value: Hashable, Label>(value:, label:)` [`lily/Core/UI/Components/ChevronLink.swift:ChevronLink`], a
  `.plain` `NavigationLink(value:)` whose label and `.caption2` `DesignTokens.Symbols.chevron` read `.secondary`;
  `ValidationHint(_ message: String)` [`lily/Core/UI/Components/ValidationHint.swift:ValidationHint`], a `Label` of the
  words in `Color.secondary` (the fixed label colour, not the hierarchical `.secondary`, which inside a form footer
  steps down to tertiary) and `DesignTokens.Symbols.error` in `Color.lilyAccent`, hidden from accessibility, in the
  caller's font;
  `CardHeader<Chips>(startsAt: Date, chips: (_ badgeCapped: Bool) -> Chips)` [`lily/Core/UI/Components/CardHeader.swift:CardHeader`]
  (`ViewThatFits`: one row with `chips(true)`, else a `FlowLayout` with `chips(false)` over
  `Text(startsAt, format: .relative(presentation: .named))`); `CaptionedControl<Content>(_ title:, content:)`
  [`lily/Core/UI/Components/CaptionedControl.swift:CaptionedControl`];
  `PlaceLine(name:, distance: String? = nil, font: Font = .subheadline)` [`lily/Core/UI/Components/PlaceLine.swift:PlaceLine`].
- Marks and rows: `AvatarCircle(initials:, systemImage: String? = nil, size: CGFloat = DesignTokens.Layout.avatarSize, tint: Tint = .accent, glyphFont: Font? = nil, glyphColor: Color? = nil)`,
  a glyph-only `init(systemImage:, size:, tint:, glyphFont:, glyphColor:)`, `enum Tint { case accent, secondary }`
  [`lily/Core/UI/Components/AvatarCircle.swift:AvatarCircle`]; `GlassGlyph(systemName:)`
  [`lily/Core/UI/Components/GlassGlyph.swift:GlassGlyph`]; `UnreadDot()` [`lily/Core/UI/Components/UnreadDot.swift:UnreadDot`];
  `nonisolated extension String { var initials: String }` [`lily/Core/UI/Components/String+Initials.swift:String.initials`];
  `ConversationRow<Title, Trailing>(caption:, avatar: AvatarCircle, title:, trailing:)` with
  `init(caption:, hasUnread: Bool, avatar:, title:)` where `Trailing == UnreadDot?`, and `AvatarRowDivider()`
  [`lily/Core/UI/Components/ConversationRow.swift:ConversationRow`, `AvatarRowDivider`]; `CaptionedTitle<Title>(lines: [String], title:)`
  (the title in `LilyTheme.Fonts.itemTitle` over one caption line per entry, the text column `ConversationRow` and `TileContent` share)
  [`lily/Core/UI/Components/CaptionedTitle.swift:CaptionedTitle`];
  `SettingsLinkRow(title:, subtitle:, systemImage:, identifier:, action:)` (a whole-card `GlassCard` button with icon,
  title, subtitle and chevron, `.buttonStyle(.plain)`, `.lilyHoverable()`; Profile's display name and contact rows)
  [`lily/Core/UI/Components/SettingsLinkRow.swift:SettingsLinkRow`];
  `EntriesBar(fillRatio: Double, text: String, isFull: = false, isNearlyFull: = false, showsTrack: = true)` with
  `init(event: SportEvent)` (the track only while `event.playerLimit.hasCapacity`) and `init(tournament: Tournament)`
  [`lily/Core/UI/Components/EntriesBar.swift:EntriesBar`]; its height is `DesignTokens.Layout.capacityBarHeight`.
- Carousel: `TileCarousel<Item: Identifiable, SeeAll: Hashable, Tile>(items:, title:, seeAll:, seeAllIdentifier:, identifier:, rows: Int = 1, tileHeight: CGFloat, tile: (Item, _ fillsWidth: Bool) -> Tile)`,
  `TileLink<Value: Hashable, Tile>(value:, identifier:, tile:)`, `TileContent(avatar: AvatarCircle, title:, lines: [String])` (an `HStack` of the avatar, a `CaptionedTitle` and a spacer)
  [`lily/Core/UI/Components/TileCarousel.swift:TileCarousel`, `TileLink`, `TileContent`].
- Lists and states: `EmptyStateView(symbolName:, title:, message:, actionTitle: String? = nil, action: (() -> Void)? = nil)`
  and `static loadFailed(title:, message:, actionTitle: String? = nil, action: (() -> Void)? = nil) -> EmptyStateView`
  (the one place that fixes `DesignTokens.Symbols.error` for a failed load; ten sites use it)
  [`lily/Core/UI/Components/EmptyStateView.swift:EmptyStateView`]; `ListSegment<Content>(state: ListState, empty: EmptyStateView, failed: EmptyStateView, content:)`
  [`lily/Core/UI/Components/ListSegment.swift:ListSegment`]; `FadingPresence<Content>(isShown: Bool, animation: Animation, content:)`,
  `content` while `isShown`, fading in and out on the caller's `animation` inside a `ZStack` that keeps its place (the
  chat's first-page spinner and empty state pass `.firstPageFade`) [`lily/Core/UI/Components/FadingPresence.swift:FadingPresence`].
- Fields: `lilyField()` (capsule glass) and `lilyMultilineField()` (rounded rect), both `frame(minHeight: DesignTokens.Layout.fieldHeight)`
  [`lily/Core/UI/Components/FieldModifiers.swift:View.lilyField`, `View.lilyMultilineField`].
  `GrowingTextView: UIViewRepresentable` (`text: Binding<String>`, `isFocused: Binding<Bool>`, `placeholder: String`,
  `maxLines: Int`, `accessibilityIdentifier: String`, `onReturn: (EventModifiers) -> KeyPress.Result`) with
  `nonisolated enum Metrics { static func height(fitting contentHeight: CGFloat, lineHeight: CGFloat, maxLines: Int) -> CGFloat }`
  and a `Coordinator: NSObject, UITextViewDelegate`; `final class PlaceholderTextView: UITextView` (`placeholder`,
  `onReturn`, `static let returnKeyFlags`, `refreshPlaceholder()`, `takeFocus()`);
  `nonisolated extension EventModifiers { init(_ flags: UIKeyModifierFlags) }`
  [`lily/Core/UI/Components/GrowingTextView.swift:GrowingTextView`, `GrowingTextView.Metrics`, `PlaceholderTextView`, `EventModifiers.init(_:)`].
- Dropdowns: `FilterDropdownButton<Panel>(title:, isActive:, identifier:, onPresentedChange: ((Bool) -> Void)? = nil, panel: (_ dismiss: @escaping () -> Void) -> Panel)`
  (a popover) and `DropdownPanel<Accessory, Content>(title:, scrolls: Bool = false, accessory:, onDone:, content:)`
  with an accessory-less `init` [`lily/Core/UI/Components/FilterDropdown.swift:FilterDropdownButton`, `DropdownPanel`];
  `TypeFilterButton(typeFilter: Binding<EventType?>, identifier:)` and `TypeFilterPanel(typeFilter:, onDone:)`
  [`lily/Core/UI/Components/TypeFilterButton.swift:TypeFilterButton`, `TypeFilterPanel`].
- Errors and sheets: `ErrorPopupView(presented: PresentedError, onDismiss:)` and `func errorPopup(_ errorCenter: ErrorCenter) -> some View`
  [`lily/Core/UI/Components/ErrorPopup.swift:ErrorPopupView`, `View.errorPopup`];
  `DraftSheet<Model: DraftSubmitting, Form>(viewModel:, title:, submitTitle:, cancelIdentifier:, submitIdentifier:, errorCenter: ErrorCenter, form: (Model) -> Form)`
  [`lily/Core/UI/Components/DraftSheet.swift:DraftSheet`]: `NavigationStack { ContentScreen { form(viewModel) } }`
  with `.cancellationAction` (`AppBranding.Forms.cancel`) and `.confirmationAction` (`DraftSubmitButton`) toolbar
  items, `lilyFormSheet(errorCenter:lockedWhile: viewModel.isSubmitting)` (sizing, grabber, dismissal lock, popup).

## Invariants

- Aurora: frozen when `!motion.allowsMovement || auroraFrozen` (`\.motion`, see [Layout](../Layout/EGM.md); never
  `accessibilityReduceMotion` directly); then the `TimelineView` is paused, the time is 0 (the t = 0
  frame) and the opacity 1, otherwise the opacity is `AuroraReveal.opacity(at: context.date)`; mesh and grain sit in
  one inner `ZStack` so they layer [`lily/Core/UI/Components/AuroraBackground.swift:AuroraBackground`].
  `ContentScreen` gives it `windowHeight.map { $0 - proxy.safeAreaInsets.top }`, unconstrained while `\.windowHeight`
  is `nil` [`lily/Core/UI/Components/ContentScreen.swift:ContentScreen`]. `FilmGrainOverlay.tiles` is a
  `private static let` built once; the body renders only `if !Self.tiles.isEmpty`
  [`lily/Core/UI/Components/FilmGrainOverlay.swift:FilmGrainOverlay`].
- Buttons: `lilyProminentButton` and `lilyGlassButton` apply `buttonBorderShape(.capsule)`, `buttonSizing(sizing)` and
  `LilyTheme.Fonts.button`, and write `\.controlSize` only when `controlSize != nil`, so `controlSize: nil` keeps a
  toolbar's inherited size; no `frame` is put on a label [`lily/Core/UI/Components/ButtonModifiers.swift:View.lilyButtonMetrics`].
  `lilyGlassButton` tints `labelColor ?? .accentColor` because `tint(nil)` would not restore the accent
  [`lily/Core/UI/Components/ButtonModifiers.swift:View.lilyGlassButton`]. The accent never colours text below the
  headline size: `LilyTextButtonStyle` draws the label in `color` (ink by default) while enabled and `.secondary` while
  not (`@Environment(\.isEnabled)`), at `DesignTokens.Opacity.pressedTextButton` while pressed, and applies
  `tappableLabel(minHeight:)` itself, so the hit area is the style's and no site adds one
  [`lily/Core/UI/Components/ButtonModifiers.swift:LilyTextButtonStyle.makeBody`]; `lilyToolbarTextButton` is a tint
  and not a style because a `.borderless` or custom style collapses an iOS 26 toolbar item to an icon-sized circle and
  the bar dims a disabled tinted label itself [`lily/Core/UI/Components/ButtonModifiers.swift:View.lilyToolbarTextButton`].
  `ValidationHint` puts the accent on the glyph only, `ChevronLink` on nothing: the chevron is the link's cue
  [`lily/Core/UI/Components/ValidationHint.swift:ValidationHint`, `lily/Core/UI/Components/ChevronLink.swift:ChevronLink`].
  `BusyButton` is
  `.disabled(action == nil || isBusy)` and unstyled [`lily/Core/UI/Components/BusyButton.swift:BusyButton`];
  `DraftSubmitButton` is `.disabled(!isEnabled)`, shows a small `ProgressView` labelled `title` while submitting and is
  `lilyProminentButton(sizing: .fitted, controlSize: nil)` [`lily/Core/UI/Components/DraftSubmitButton.swift:DraftSubmitButton`];
  `ProviderButton` is `.disabled(isDisabled || isLoading)` [`lily/Core/UI/Components/ProviderButton.swift:ProviderButton`].
- Chips: `lilyChip` is always a glass capsule and `tappableLabel` a minimum, not fixed, height
  [`lily/Core/UI/Components/ChipModifiers.swift:View.lilyChip`, `View.tappableLabel`]; `ChoiceChip` is
  `.buttonStyle(.plain)` with the `.isSelected` trait when selected [`lily/Core/UI/Components/ChoiceChip.swift:ChoiceChip`];
  `EventTypeChips` shows the "any" chip only `if let anyTitle` and iterates exactly `EventType.known`
  [`lily/Core/UI/Components/EventTypeChips.swift:EventTypeChips`].
- `FlowLayout`: line width `proposal.width ?? .infinity`; a subview is measured at `.unspecified` and re-measured at the
  line width only when `FlowArrangement.proposedWidth` returns one (an over-wide label truncates within the line);
  placement advances by `measured.width + spacing` and `row.height + rowSpacing` from `bounds.minX`/`minY`; no cache
  [`lily/Core/UI/Components/FlowLayout.swift:FlowLayout.sizeThatFits`, `FlowLayout.placeSubviews`, `FlowLayout.sizes(of:fitting:)`].
- `GrowingTextView`: `Metrics.height` = `min(max(contentHeight, lineHeight), lineHeight * CGFloat(max(maxLines, 1)))`
  [`lily/Core/UI/Components/GrowingTextView.swift:GrowingTextView.Metrics.height`]; `updateUIView` replaces the UIKit
  text only when `view.text != text` (dropping marked text) [`lily/Core/UI/Components/GrowingTextView.swift:GrowingTextView.updateUIView`];
  focus is taken in a deferred `Task` and resigned at once [`lily/Core/UI/Components/GrowingTextView.swift:GrowingTextView.syncFocus`].
  `PlaceholderTextView`: the placeholder is hidden iff the text is non-empty
  [`lily/Core/UI/Components/GrowingTextView.swift:PlaceholderTextView.refreshPlaceholder`]; `scrollsToTop` is false from
  `init`, so a chat's transcript is the one scroll view answering a tap on the status bar
  [`lily/Core/UI/Components/GrowingTextView.swift:PlaceholderTextView.init(frame:textContainer:)`]; `canBecomeFirstResponder`
  is `acceptsFocus && super.canBecomeFirstResponder`, cleared by `willMove(toWindow: nil)` and set again by a hit,
  `accessibilityActivate()` or `takeFocus()`, so a field that left the window does not re-take the keyboard by itself
  [`lily/Core/UI/Components/GrowingTextView.swift:PlaceholderTextView.canBecomeFirstResponder`]; hardware Return for
  `returnKeyFlags = [[], .shift, .numericPad, [.shift, .numericPad]]` calls `onReturn(EventModifiers(flags))` and
  inserts `"\n"` only on `.ignored`, during an IME composition it only calls `unmarkText()`, and `.command` is not
  intercepted [`lily/Core/UI/Components/GrowingTextView.swift:PlaceholderTextView.keyCommands`, `PlaceholderTextView.returnPressed`];
  `init?(coder:)` is unavailable [`lily/Core/UI/Components/GrowingTextView.swift:PlaceholderTextView.init(coder:)`].
- Error popup: drawn only when `errorCenter.isTopPresenter(presenter)` and `errorCenter.current` is set (`presenter` is
  a per-mount `@State UUID`), so the topmost mount draws; the auto-dismiss `.task(id: presented.id)` sleeps
  `errorCenter.autoDismissDelay` (none means no timer), checks cancellation, then calls `errorCenter.dismiss(presented.id)`;
  the swipe dismiss fires only for `translation.height < 0` past `DesignTokens.Layout.swipeDismissDistance`
  [`lily/Core/UI/Components/ErrorPopup.swift:ErrorPopupModifier`]. `ErrorPopupView` is one accessibility element
  (`.combine`) [`lily/Core/UI/Components/ErrorPopup.swift:ErrorPopupView`].
- `DraftSheet`: cancel is `lilyToolbarTextButton()` and `.disabled(viewModel.isSubmitting)`, interactive dismiss is
  disabled while submitting and the popup is mounted on the sheet root, both through
  `lilyFormSheet(errorCenter:lockedWhile:)` [`lily/Core/UI/Layout/FormSheet.swift:View.lilyFormSheet`]; submit is
  enabled by `canSubmit`, the sheet dismisses itself in `.onChange(of: viewModel.isDone)`
  [`lily/Core/UI/Components/DraftSheet.swift:DraftSheet`].
- `TileCarousel` renders nothing unless `!items.isEmpty`; its "See all" is a `NavigationLink(value: seeAll)` under
  `lilyTextButton()`; it is a `TileGrid` when `sizeClass == .regular`, else a
  view-aligned horizontal `LazyHGrid`; the grid applies `.accessibilityElement(children: .contain)` before
  `.accessibilityIdentifier(identifier)` [`lily/Core/UI/Components/TileCarousel.swift:TileCarousel.body`, `TileCarousel.grid`, `TileCarousel.scroll`].
- `EntriesBar` draws the track only `if showsTrack`, fills `proxy.size.width * fillRatio` with no clamp here, and picks
  `isFull` → `.secondary`, `isNearlyFull` → `Color.lilySecondary`, else `Color.lilyAccent`
  [`lily/Core/UI/Components/EntriesBar.swift:EntriesBar`]. `AvatarCircle` is always `size` by `size`, a glass circle,
  `.accessibilityHidden(true)`, and `systemImage` wins over `initials` [`lily/Core/UI/Components/AvatarCircle.swift:AvatarCircle`].
  `String.initials` takes the first character of the first two space-separated words, uppercased
  [`lily/Core/UI/Components/String+Initials.swift:String.initials`].
- `FilterDropdownButton` stays a popover on compact widths (`presentationCompactAdaptation(.popover)`); `DropdownPanel`
  is fixed at `DesignTokens.Layout.filterPanelWidth` and scrolls only `if scrolls`
  [`lily/Core/UI/Components/FilterDropdown.swift:FilterDropdownButton`, `DropdownPanel`]. `EmptyStateView` shows its
  button only when both `actionTitle` and `action` are set [`lily/Core/UI/Components/EmptyStateView.swift:EmptyStateView`];
  `ListSegment` evaluates `content()` only for `.content` [`lily/Core/UI/Components/ListSegment.swift:ListSegment`].
- Isolation: `String.initials`, `GrowingTextView.Metrics` and `EventModifiers.init(_:)` are `nonisolated`; every other
  type is main-actor isolated.

## Side Effects

- Wall-clock redraw: `AuroraBackground`'s `TimelineView` reads `context.date` each frame
  [`lily/Core/UI/Components/AuroraBackground.swift:AuroraBackground`]; `FilmGrainOverlay` builds its tiles once, on
  first access of `Self.tiles` [`lily/Core/UI/Components/FilmGrainOverlay.swift:FilmGrainOverlay`].
- Tasks: `BusyButton` and `DraftSubmitButton` spawn `Task { await action() }` per tap
  [`lily/Core/UI/Components/BusyButton.swift:BusyButton`, `lily/Core/UI/Components/DraftSubmitButton.swift:DraftSubmitButton`];
  `GrowingTextView.syncFocus` spawns `Task { @MainActor in view.takeFocus() }`; `ErrorPopupModifier` sleeps in
  `.task(id:)`; `DraftSheet` runs `.task { await viewModel.prepare() }` [`lily/Core/UI/Components/DraftSheet.swift:DraftSheet`].
- Shared state: `errorPopup` calls `ErrorCenter.beginPresenting(presenter)` on `onAppear`, `endPresenting(presenter)`
  on `onDisappear` and `dismiss(id)` on tap, swipe or timeout [`lily/Core/UI/Components/ErrorPopup.swift:ErrorPopupModifier`];
  `DraftSheet` calls the `\.dismiss` action on cancel and when `isDone` turns true.
- Environment writes: `\.controlSize` from the button modifiers when non-nil
  [`lily/Core/UI/Components/ButtonModifiers.swift:View.lilyButtonMetrics`]; `.tint(Color.lilyInk)` from
  `lilyToolbarTextButton()` on the item it styles; `.tint(Color.lilyAccent)` from
  `DropdownPanel` and `DraftSheet`, `.presentationBackground(.clear)` from `DropdownPanel`
  [`lily/Core/UI/Components/FilterDropdown.swift:DropdownPanel`].
- UIKit: the `Coordinator` writes the `text` and `isFocused` bindings from the `UITextViewDelegate` callbacks;
  `PlaceholderTextView.init` adds the placeholder label and a `NotificationCenter` observer for
  `UITextView.textDidChangeNotification` (object `self`, no explicit `removeObserver`); `takeFocus()` calls
  `becomeFirstResponder()` [`lily/Core/UI/Components/GrowingTextView.swift:GrowingTextView.Coordinator`, `PlaceholderTextView`].
- Navigation and bindings: `TileCarousel`, `TileLink`, `ChevronLink` and (through it) `OwnerTitleBlock` push through
  `NavigationLink(value:)`;
  `FilterDropdownButton` reports `onPresentedChange?(isPresented)` on every change; `TypeFilterPanel` writes the
  `EventType?` binding [`lily/Core/UI/Components/TileCarousel.swift:TileLink`,
  `lily/Core/UI/Components/FilterDropdown.swift:FilterDropdownButton`, `lily/Core/UI/Components/TypeFilterButton.swift:TypeFilterPanel`].
- Randomness: the per-mount `UUID()` presenter token of `ErrorPopupModifier`. No logging, no I/O, no network, no haptics.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; `lilyTests/UI/GrowingTextViewTests.swift`,
  `PlaceholderTextViewTests.swift` and `InitialsTests.swift` pin the testable logic). Every component is checked as
  rendered, by screenshot on a simulator per `AGENTS.md`; `lilyUITests` drive them through `AccessibilityIdentifiers`.
