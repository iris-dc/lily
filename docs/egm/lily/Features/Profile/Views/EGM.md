# Profile Views

Source: `lily/Features/Profile/Views/`

## Overview

The profile sheet (`MainTabView` presents it from the corner button on every tab root since 2026-11-07; before that a
tab): the caller's name and bio as the backend holds them (each with the card and sheet that change it) with
a link row into `SettingsScreen` (the language and currency dropdown cards, the contact (feedback) card, the privacy and
terms links and Sign out), or the guest prompt with Sign in and the language, currency and contact rows inline — a guest
gets no Settings screen (2026-11-07). `ProfileView` and the pushed `SettingsScreen` re-render in place when the language
changes rather than being rebuilt like the other tabs, whose rebuild would crossfade over the pick made here.
`SettingsChoiceRow` is the shared dropdown card the language and currency rows are built from.

## Interface

- `ProfileView(dependencies: AppDependencies, language: AppLanguage)` `[lily/Features/Profile/Views/ProfileView.swift:ProfileView]`:
  the profile sheet's content — a `NavigationStack` (the sheet's stack) with `ContentScreen`, title
  `AppBranding.profileTitle`; the root content carries `.accessibilityElement(children: .contain)` then
  `AccessibilityIdentifiers.profileSheet`, and the stack mounts `.errorPopup(dependencies.errorCenter)` itself (the
  topmost mount draws; the app root's popup sits below the sheet) (2026-11-07); signed in: an `AvatarCircle` of the
  profile name's initials (a glyph while the name is unknown), the name from `dependencies.profile` (a small spinner
  while the first load runs) and the email, then `DisplayNameRow(store:action:)`, `AboutRow(store:action:)` and the
  Settings link row (a `SettingsLinkRow` titled `AppBranding.Settings.title` with `AppBranding.Settings.rowSubtitle`,
  `DesignTokens.Symbols.settings` and identifier `AccessibilityIdentifiers.profileSettings`) pushing `SettingsScreen`
  through `navigationDestination(isPresented:)`; guest: `AppBranding.guestProfileTitle`, `guestProfileMessage` and a
  prominent Sign in, then `LanguageRow`, `CurrencyRow` and `FeedbackRow(action:)` inline; sheets
  `SignInSheet(session:errorCenter:)`, `DisplayNameSheet(viewModel:errorCenter:)` over
  `dependencies.makeDisplayNameViewModel()` and `AboutSheet(viewModel:errorCenter:)` over `dependencies.makeAboutViewModel()`.
- `SettingsScreen(dependencies: AppDependencies, language: AppLanguage)`
  `[lily/Features/Profile/Views/SettingsScreen.swift:SettingsScreen]`: the signed-in settings pushed from the profile
  root (2026-11-07), title `AppBranding.Settings.title`, a `ScrollView` that scrolls only past the screen
  (`.scrollBounceBehavior(.basedOnSize)`): `LanguageRow`, `CurrencyRow`, `FeedbackRow` presenting
  `FeedbackSheet(viewModel:errorCenter:)` over `dependencies.makeFeedbackViewModel()`, two `SettingsLinkRow` legal
  links — `AppBranding.Moderation.privacyLink` / `AppBranding.Settings.privacySubtitle` / `DesignTokens.Symbols.privacy`
  / `AccessibilityIdentifiers.settingsPrivacy` opening `AppConfig.Moderation.privacyURL`, and `Moderation.termsLink` /
  `Settings.termsSubtitle` / `Symbols.terms` / `settingsTerms` opening `termsURL`, both through
  `@Environment(\.openURL)` — Sign out, a full-width `lilyTextButton()` text action (identifier
  `AccessibilityIdentifiers.settingsSignOut`) moved off the profile header, and Delete account (2026-11-07), a
  full-width destructive `lilyTextButton(color: .red)` (identifier `settingsDeleteAccount`) presenting
  `DeleteAccountSheet(viewModel: dependencies.makeDeleteAccountViewModel(), errorCenter:)` in a sheet.
- `DeleteAccountSheet(viewModel: DeleteAccountViewModel, errorCenter: ErrorCenter)`
  `[lily/Features/Profile/Views/DeleteAccountSheet.swift:DeleteAccountSheet]` (2026-11-07, the deletion contract):
  a `NavigationStack` titled `AppBranding.DeleteAccount.title` under
  `.lilyFormSheet(errorCenter:lockedWhile: viewModel.isLocked)` and `.presentationDetents([.large])`, presented from
  Settings and from `TermsSheet`. Three states: `summary` (the view model's plural lines — zero counts dropped — then
  `DeleteAccount.approximate` only when lines show, the always-true `DeleteAccount.messagesSentence`, the
  `irreversible` note, and the prominent confirm button `deleteAccountConfirm` opening a `confirmationDialog`
  (`dialogTitle` / destructive `confirmAction` / `irreversible` as the message) whose destructive action runs
  `viewModel.confirmDeletion()`); `deleting` (a spinner with `DeleteAccount.deleting`); `acknowledgment` (an
  `EmptyStateView` with `Tombstone.symbol`, `deletedTitle`, `deletedMessage` and the prominent `acknowledgeAction`
  button `deleteAccountAcknowledge` running `viewModel.acknowledge()`). The toolbar's Cancel (`deleteAccountCancel`)
  exists only while `!viewModel.isLocked`; `.task` runs `viewModel.prepare()`.
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
- `AboutRow(store: ProfileStore, action: () -> Void)` `[lily/Features/Profile/Views/AboutRow.swift:AboutRow]`: a
  `SettingsLinkRow` titled `AppBranding.About.title` ("About you") with `DesignTokens.Symbols.about`, identifier
  `AccessibilityIdentifiers.profileAbout`; the subtitle is `store.bio` when written (cut to the row's two lines), else
  `AppBranding.About.emptySubtitle` ("Tell other players about yourself").
- `AboutSheet(viewModel: AboutViewModel, errorCenter: ErrorCenter)` `[lily/Features/Profile/Views/AboutSheet.swift:AboutSheet]`:
  a `DraftSheet` titled `AppBranding.About.title` with Save (`AccessibilityIdentifiers.profileAboutSave`) and Cancel
  (`profileAboutCancel`) around one `Form` `TextField(axis: .vertical)` (`profileAboutField`; sentences capitalised,
  `DesignTokens.Layout.aboutFieldLines` 3...8 lines) whose footer is the draft's `hint` as a `ValidationHint`, else
  `AppBranding.About.footer`.
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
  `.auth` `[lily/Features/Profile/Views/ProfileView.swift:openFeedback]`; a signed-in caller reaches the form from
  Settings, whose row presents the sheet directly `[lily/Features/Profile/Views/SettingsScreen.swift:SettingsScreen]`.
- The signed-in root holds exactly the header, the name and bio cards and the Settings link; language, currency, the
  contact card and Sign out moved into `SettingsScreen`, whose list ends in Sign out then Delete account (2026-11-07,
  the relocation contract's session-state matrix and its pinned summary-rendering and teardown rules: zero-count
  summary lines are dropped, the messages sentence always renders, the sheet stays locked from the confirm on, the
  acknowledgment is hosted by `DeleteAccountSheet` itself and only its tap triggers the account-deleted session end),
  and the guest root keeps the three rows inline — guests get no Settings screen. The rows keep their identifiers
  (`profile-language`, `profile-currency`, `profile-feedback`) wherever they sit, so UI tests change navigation only.
- `FeedbackRow` (on the guest root and on Settings), `DisplayNameRow` and `AboutRow` (the last two also take the store
  object) are given `.id(language)` because a closure input is not a change SwiftUI counts, so they would keep the old
  copy `[lily/Features/Profile/Views/ProfileView.swift:ProfileView]`; the Settings link row and the legal rows take
  their copy as plain inputs, which the language re-render recomputes.
- The profile loads lazily, once per session, from the `.task(id: session.state.user?.id) { await
  profile.loadIfNeeded() }` on `ProfileView`'s `NavigationStack` — the sheet's content, so it runs only while the
  sheet is up and a user who never opens the profile costs no request (the corner button reads the snapshot alone);
  the header shows the backend's name,
  a spinner only while the first load runs and nothing when it failed (the cards below still write)
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

- `session.signOut()` in a `Task` from Settings' Sign out `[lily/Features/Profile/Views/SettingsScreen.swift:signOutButton]`.
- The delete flow's network and session effects run through `DeleteAccountViewModel` (`../ViewModels/EGM.md`): the
  plan load on the sheet's `.task`, the `DELETE` and the poll from the dialog's destructive action, the
  account-deleted session end from the acknowledge tap `[lily/Features/Profile/Views/DeleteAccountSheet.swift:DeleteAccountSheet]`.
- Sheets: `SignInSheet` (a guest's Sign in, or feedback asked for as a guest), `DisplayNameSheet` from
  `dependencies.makeDisplayNameViewModel()` and `AboutSheet` from `dependencies.makeAboutViewModel()`
  `[lily/Features/Profile/Views/ProfileView.swift:ProfileView]`; `FeedbackSheet` from
  `dependencies.makeFeedbackViewModel()` on Settings `[lily/Features/Profile/Views/SettingsScreen.swift:SettingsScreen]`.
- `openURL` into the browser from the legal rows (`AppConfig.Moderation.privacyURL`, `termsURL`)
  `[lily/Features/Profile/Views/SettingsScreen.swift:legalRow]`.
- `ProfileStore.loadIfNeeded()` (`GET /api/profile` once per session) from the `.task(id: session.state.user?.id) {
  await profile.loadIfNeeded() }` on `ProfileView`'s `NavigationStack`
  `[lily/Features/Profile/Views/ProfileView.swift:ProfileView]`.
- `LanguageStore.select(_:)` and `CurrencyStore.select(_:)` on a pick `[lily/Features/Profile/Views/LanguageRow.swift:selection]`,
  `[lily/Features/Profile/Views/CurrencyRow.swift:selection]`.
- An info log under `.auth` when a guest asks to send feedback `[lily/Features/Profile/Views/ProfileView.swift:openFeedback]`.
- No network, disk or timers of their own; `#Preview` blocks use `AppDependencies.makeMock()`.

## Verification

- Run: `./scripts/ci.sh unit` (`lilyTests/Preferences` covers the choice stores behind these rows, `lilyTests/Profile`
  the store, the editors' model, `SettingsConfigTests` — the Settings glyphs and copy keys, the delete copy and the
  launch-argument literal — and `DeleteAccountViewModelTests`); `./scripts/ci.sh ui`
  (`LilyProfileTests` walks the display name and the "About you" cards and sheets; `LilySettingsTests` the Settings
  push, the guest root, a language pick inside Settings, Sign out, the delete flow end to end on the mock backend and
  the deleted sender's tombstone under `-mock-deleted-user`).
