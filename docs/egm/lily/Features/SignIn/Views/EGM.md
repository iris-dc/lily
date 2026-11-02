# SignIn: Views

Source: `lily/Features/SignIn/Views/`

## Overview

The sign-in sheet and the email form pushed inside it. `SignInSheet` is presented from the landing and from the guest
prompts: a navigation stack with Close, the title and three `ProviderButton`s centred in the medium detent, with its own
`.errorPopup` because a sheet draws above the root's. `EmailSignInView` is the email + password form whose third step is
the confirmation code; it owns the choreography that grows the sheet to the large detent before a field takes focus so
the keyboard never pushes the sheet.

Files: `lily/Features/SignIn/Views/SignInSheet.swift`, `lily/Features/SignIn/Views/EmailSignInView.swift`.

## Interface

- `[SignInSheet.swift:SignInSheet]`: `init(session: SessionController, errorCenter: ErrorCenter)`; `@State viewModel:
  SignInViewModel`, `@State restHeight: CGFloat?`, `@State detent: PresentationDetent = .medium`; reads `\.dismiss` and
  `\.dynamicTypeSize`. Body: `NavigationStack { ContentScreen { GeometryReader { ScrollView { column } } } }` with
  `.presentationDetents([.medium, .large], selection: $detent)`, `.lilyFormSheet()`, `.errorPopup(errorCenter)`.
- `[SignInSheet.swift:SignInSheet.column]`: `ScreenTitle(text: AppBranding.signInSheetTitle, subtitle:
  AppBranding.signInSheetSubtitle)` and `providers`: `ProviderButton(provider: .apple, isLoading:, isDisabled:)`,
  `ProviderButton(provider: .google, ...)`, `ProviderButton(provider: .email, isDisabled:)` in a
  `GlassEffectContainer`, under `.readableColumn()`.
- `[SignInSheet.swift:SignInSheet.closeButton]`: a trailing toolbar `Button` with `DesignTokens.Symbols.dismiss`,
  `.accessibilityLabel(AppBranding.Forms.close)` and `AccessibilityIdentifiers.signInClose`.
- `[SignInSheet.swift:SignInSheet.body]`: `.navigationDestination(isPresented: $viewModel.isEmailFormPresented) {
  EmailSignInView(session: session, detent: formDetent) }`; private `restDetent` and `formDetent: Binding<PresentationDetent>`.
- `[EmailSignInView.swift:EmailSignInView]`: `init(session: SessionController, detent: Binding<PresentationDetent>)`;
  `@State viewModel: EmailSignInViewModel`, `@FocusState focusedField: Field?` (private `enum Field { email, password,
  code }`), `@Binding detent`; reads `\.dismiss`. Body: `ContentScreen { ScrollView { ScreenTitle(text:
  viewModel.mode.title, subtitle: viewModel.subtitle); codeField or credentialFields; submitButton; resendButton (confirm
  only); modeToggle } }` under `.readableColumn()`.
- `[EmailSignInView.swift:EmailSignInView.credentialFields]`: `TextField(AppBranding.emailFieldPlaceholder)` with
  `.textContentType(.username)`, `.keyboardType(.emailAddress)`, `.textInputAutocapitalization(.never)`,
  `.autocorrectionDisabled()`, `.submitLabel(.next)`, `.lilyField()`, `AccessibilityIdentifiers.authEmail`;
  `SecureField(AppBranding.passwordFieldPlaceholder)` with `.textContentType(mode == .signUp ? .newPassword :
  .password)`, `.submitLabel(.go)`, `AccessibilityIdentifiers.authPassword`; a caption `viewModel.passwordHint`.
- `[EmailSignInView.swift:EmailSignInView.codeField]`: `TextField(AppBranding.confirmationCodePlaceholder)` with
  `.keyboardType(.numberPad)`, `.textContentType(.oneTimeCode)`, `AccessibilityIdentifiers.authConfirmationCode`.
- `[EmailSignInView.swift:EmailSignInView.submitButton]`: `lilyProminentButton()` labelled `viewModel.mode.submitLabel`
  with a small `ProgressView` while `isSubmitting`, `AccessibilityIdentifiers.authSubmit`; `resendButton`
  (`AppBranding.resendCodeAction`, `AccessibilityIdentifiers.authResendCode`); `modeToggle`
  (`viewModel.mode.toggleLabel`, `AccessibilityIdentifiers.authModeToggle`); `backButton` (`DesignTokens.Symbols.back`,
  `AppBranding.Forms.back`, `AccessibilityIdentifiers.authBack`); private `textButton(_:identifier:action:)` is a
  full-width label under `lilyTextButton(font: LilyTheme.Fonts.caption)` (`lily/Core/UI/Components/ButtonModifiers.swift`):
  ink, `.secondary` while disabled, the 44pt hit area from the style.
- `[EmailSignInView.swift:View.firstTapGrowsTheSheet]`: `private extension View`; `func firstTapGrowsTheSheet(detent:
  PresentationDetent, action: @escaping () -> Void) -> some View`, a clear tap-catching overlay present only while
  `detent != .large`, hidden from accessibility.

## Invariants

- `[SignInSheet.swift:SignInSheet.body]`: `.onChange(of: session.state.user) { if user != nil { dismiss() } }`: the sheet
  closes as soon as a user exists (guests are already inside the app); `.onDisappear { viewModel.cancel() }` so nothing
  finishes signing in once the sheet is gone.
- `[SignInSheet.swift:SignInSheet.restDetent]`: `.large` at accessibility type sizes, else `.medium`; applied by
  `.onChange(of: typeSize, initial: true)`; `formDetent` turns the form's `.medium` request into `restDetent`.
- `[SignInSheet.swift:SignInSheet.body]`: `restHeight = min(restHeight ?? height, height)` for `height > 0`, so the
  providers are centred in the smallest height seen whatever the sheet's current detent.
- `[EmailSignInView.swift:EmailSignInView.body]`: no field is focused on appearance; `.navigationBarBackButtonHidden(true)`
  with the form's own back button; `.onChange(of: viewModel.mode)` focuses `.code` in confirm and `.email` otherwise;
  `.onChange(of: focusedField)` sets `detent = field == nil ? .medium : .large`; `.onDisappear { viewModel.cancel() }`.
- `[EmailSignInView.swift:EmailSignInView.focus]`: `guard detent != .large else { focusedField = field; return }`;
  otherwise the detent grows first and the focus is set on the next main-queue turn.
- `[EmailSignInView.swift:EmailSignInView.goBack]`: `guard focusedField != nil else { dismiss(); return }`; otherwise
  focus is cleared and the pop is deferred one main-queue turn so the keyboard starts down first.
- `[EmailSignInView.swift:EmailSignInView.submitButton]`: `.disabled(!viewModel.canSubmit)`; `resendButton` is
  `.disabled(viewModel.isBusy)`; the password is a `SecureField`; the code field replaces the credential fields when
  `viewModel.mode == .confirm`.

## Side Effects

- Sign-in: `[SignInSheet.swift:SignInSheet.providers]` calls `viewModel.signInWithApple()`, `signInWithGoogle()`,
  `presentEmailForm()`; `[EmailSignInView.swift:EmailSignInView]` calls `viewModel.submit()` (button and the password
  field's `onSubmit`), `viewModel.resendCode()` and `viewModel.toggleMode()`, all reaching `SessionController`.
- Dismissal: `[SignInSheet.swift:SignInSheet.closeButton]`, the user `onChange`, and
  `[EmailSignInView.swift:EmailSignInView.goBack]` call `dismiss()`.
- Animation: `[EmailSignInView.swift:EmailSignInView.focus]` and the focus `onChange` animate the detent with
  `.smooth(duration: DesignTokens.Duration.normal)`; `[EmailSignInView.swift:EmailSignInView.modeToggle]` animates the
  mode switch with `.smooth(duration: DesignTokens.Duration.fast)`.
- `[EmailSignInView.swift:EmailSignInView.focus]`, `[EmailSignInView.swift:EmailSignInView.goBack]`:
  `DispatchQueue.main.async` hops for the focus and the pop.
- `[SignInSheet.swift:SignInSheet.body]`: `.errorPopup(errorCenter)` mounts the shared popup on the sheet;
  `onChange(of: proxy.size.height, initial: true)` reads geometry into state.
- No logging, disk or network calls are made directly by these views.

## Verification

- Run: `./scripts/ci.sh unit` (from the repository root; the view-model rules behind these screens are in
  `lilyTests/SignIn`; the sheet itself is exercised by the UI tests, `./scripts/ci.sh ui`).
