# Profile Views

Source: `lily/Features/Profile/Views/`

## Overview

The Profile tab: the caller's name as the backend holds it (with the card and sheet that change it) or the guest prompt
with Sign in, the language and currency settings as dropdown cards, the contact (feedback) card and Sign out.
`ProfileView` re-renders in place when the language changes
rather than being rebuilt like the other tabs, whose rebuild would crossfade over the pick made here.
`SettingsChoiceRow` is the shared dropdown card the language and currency rows are built from.

## Interface

- `ProfileView(dependencies: AppDependencies, language: AppLanguage)` `[lily/Features/Profile/Views/ProfileView.swift:ProfileView]`:
  a `NavigationStack` with `ContentScreen`, title `AppBranding.profileTitle`; signed in: an `AvatarCircle` of the
  profile name's initials (a glyph while the name is unknown), the name from `dependencies.profile` (a small spinner
  while the first load runs), the email and a Sign out glass button, then `DisplayNameRow(store:action:)`; guest:
  `AppBranding.guestProfileTitle`, `guestProfileMessage` and a prominent Sign in; then `LanguageRow`, `CurrencyRow` and
  `FeedbackRow(action:)`; sheets `SignInSheet(session:errorCenter:)`, `DisplayNameSheet(viewModel:errorCenter:)` over
  `dependencies.makeDisplayNameViewModel()` and `FeedbackSheet(viewModel:errorCenter:)`.
- `DisplayNameRow(store: ProfileStore, action: () -> Void)` `[lily/Features/Profile/Views/DisplayNameRow.swift:DisplayNameRow]`:
  a `SettingsLinkRow` (`lily/Core/UI/Components`) titled `AppBranding.DisplayName.title` with
  `DesignTokens.Symbols.profile`, identifier `AccessibilityIdentifiers.profileName`; the subtitle is
  `AppBranding.DisplayName.defaultSubtitle` ("Choose a name other players will see") while `store.isDefaultName`, else
  `subtitle` ("What other players see").
- `DisplayNameSheet(viewModel: DisplayNameViewModel, errorCenter: ErrorCenter)`
  `[lily/Features/Profile/Views/DisplayNameSheet.swift:DisplayNameSheet]`: a `DraftSheet` titled
  `AppBranding.DisplayName.title` with Save (`AccessibilityIdentifiers.profileNameSave`) and Cancel (`profileNameCancel`)
  around one `Form` `TextField` (`profileNameField`; words capitalised, `.name` content type, no autocorrection) whose
  footer is the draft's `hint` as a `ValidationHint` (`lily/Core/UI/Components`), else `AppBranding.DisplayName.footer`.
- `LanguageRow(language: LanguageStore)` `[lily/Features/Profile/Views/LanguageRow.swift:LanguageRow]`: choices "System"
  (`AppBranding.Settings.systemLanguage`) plus every `AppLanguage.allCases` by its `nativeName`; identifier
  `AccessibilityIdentifiers.profileLanguage`.
- `CurrencyRow(currency: CurrencyStore)` `[lily/Features/Profile/Views/CurrencyRow.swift:CurrencyRow]`: choices
  "System (<region code>)" plus `AppConfig.Currency.offered`, each named through `Price.name(for:locale:)` in the
  app's locale (`@Environment(\.locale)`); the card shows `preference.fixedCode` or the system title; identifier
  `AccessibilityIdentifiers.profileCurrency`.
- `SettingsChoice<Value: Hashable>: Identifiable` `[lily/Features/Profile/Views/SettingsChoiceRow.swift:SettingsChoice]`:
  `value`, `title`; `id` is the value.
- `SettingsChoiceRow<Value: Hashable>(title:systemImage:value:identifier:choices:selection: Binding<Value>)`
  `[lily/Features/Profile/Views/SettingsChoiceRow.swift:SettingsChoiceRow]`: a `GlassCard` button that opens a popover
  of rows with a mark on the current one.

## Invariants

- Feedback needs an account: a guest tapping the contact card gets the sign-in sheet instead, logged at info under
  `.auth` `[lily/Features/Profile/Views/ProfileView.swift:openFeedback]`.
- `FeedbackRow` and `DisplayNameRow` (which also takes the store object) are given `.id(language)` because a closure
  input is not a change SwiftUI counts, so they would keep the old copy `[lily/Features/Profile/Views/ProfileView.swift:ProfileView]`.
- The profile loads lazily, once per session, from the `.task(id: session.state.user?.id) { await
  profile.loadIfNeeded() }` on `ProfileView`'s `NavigationStack`, so a user who never opens Profile costs no request; the header shows the backend's name,
  a spinner only while the first load runs and nothing when it failed (the card below still renames)
  `[lily/Features/Profile/Views/ProfileView.swift:ProfileView]`, `[lily/Features/Profile/Views/ProfileView.swift:signedIn]`.
- A pick applies at once through the store's `select(_:)`, with no animation
  `[lily/Features/Profile/Views/LanguageRow.swift:selection]`, `[lily/Features/Profile/Views/CurrencyRow.swift:selection]`,
  `[lily/Core/Localization/LanguageStore.swift:LanguageStore.select]`, `[lily/Core/Currency/CurrencyStore.swift:CurrencyStore.select]`.
- The offered currencies are `AppConfig.Currency.offered` (EUR, USD, GBP, PLN, CHF, CZK, HUF, RON, SEK, NOK, DKK, UAH,
  CAD, BRL) `[lily/Features/Profile/Views/CurrencyRow.swift:choices]`,
  `[lily/Config/AppConfig+Currency.swift:AppConfig.Currency.offered]`; the languages are `AppLanguage.allCases`
  `[lily/Features/Profile/Views/LanguageRow.swift:choices]`, `[lily/Core/Localization/Models/AppLanguage.swift:AppLanguage]`.
- The dropdown is a popover, not a `Menu` (iOS morphs a menu's label into the menu and empties the card's slot); it
  opens upward (`arrowEdge: .bottom`), takes the card's width up to `DesignTokens.Layout.dropdownMaxWidth` (400) and
  caps its height at `DesignTokens.Layout.dropdownRows` (6) rows of a `@ScaledMetric` row height seeded from
  `DesignTokens.Layout.controlHeight` (44), so it ends on a row's edge
  `[lily/Features/Profile/Views/SettingsChoiceRow.swift:SettingsChoiceRow]`, `[lily/Config/DesignTokens+Settings.swift]`,
  `[lily/Config/DesignTokens.swift:DesignTokens.Layout.controlHeight]`.
- The current choice carries the `.isSelected` trait and a check mark; a pick closes the popover before writing the
  selection `[lily/Features/Profile/Views/SettingsChoiceRow.swift:list]`.
- The card's value is one line with `DesignTokens.Layout.menuLabelMinimumScale` (0.8)
  `[lily/Features/Profile/Views/SettingsChoiceRow.swift:SettingsChoiceRow]`, `[lily/Config/DesignTokens+Settings.swift]`.

## Side Effects

- `session.signOut()` in a `Task` from the Sign out button `[lily/Features/Profile/Views/ProfileView.swift:signedIn]`.
- Sheets: `SignInSheet` (a guest's Sign in, or feedback asked for as a guest), `DisplayNameSheet` from
  `dependencies.makeDisplayNameViewModel()` and `FeedbackSheet` from `dependencies.makeFeedbackViewModel()`
  `[lily/Features/Profile/Views/ProfileView.swift:ProfileView]`.
- `ProfileStore.loadIfNeeded()` (`GET /api/profile` once per session) from the `.task(id: session.state.user?.id) {
  await profile.loadIfNeeded() }` on `ProfileView`'s `NavigationStack`
  `[lily/Features/Profile/Views/ProfileView.swift:ProfileView]`.
- `LanguageStore.select(_:)` and `CurrencyStore.select(_:)` on a pick `[lily/Features/Profile/Views/LanguageRow.swift:selection]`,
  `[lily/Features/Profile/Views/CurrencyRow.swift:selection]`.
- An info log under `.auth` when a guest asks to send feedback `[lily/Features/Profile/Views/ProfileView.swift:openFeedback]`.
- No network, disk or timers of their own; `#Preview` blocks use `AppDependencies.makeMock()`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Preferences` covers the choice stores behind these rows, `lilyTests/Profile`
  the store and the editor's model); `./scripts/ci.sh ui` (`LilyProfileTests` walks the display name card and sheet).
