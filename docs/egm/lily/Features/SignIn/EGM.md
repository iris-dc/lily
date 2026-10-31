# SignIn

Source: `lily/Features/SignIn/`

## Overview

The sign-in sheet and the email + password form it pushes, presented from the landing and from the guest prompts on Home
and Chats. The feature has no direct source files: `ViewModels` holds the two observable view models that own the
in-flight calls and the three-step email mode (sign in, sign up, confirm), and `Views` holds the sheet and the form with
their detent choreography. Every credential call goes through `SessionController` (Cognito via Amplify, declared in
`lily/Core/Auth`), which reports failures to the shared popup and logs; nothing here logs or reports. Validation is
`CredentialsValidator` (`lily/Core/Validation`); limits are `AppConfig.Auth.minimumPasswordLength` and
`AppConfig.Cognito.confirmationCodeLength`.

## Subdirectories & Boundaries

- ViewModels: [./ViewModels/EGM.md](./ViewModels/EGM.md) - `SignInViewModel` (`isEmailFormPresented`,
  `authenticatingProvider` and `isBusy` read from the session, `signInWithApple()`, `signInWithGoogle()`,
  `presentEmailForm()`, `cancel()` of the kept `signInTask`), `EmailAuthMode` (`signIn`, `signUp`, `confirm` with
  `title`, `submitLabel`, `toggleLabel`, `toggled`) and `EmailSignInViewModel` (`email`, `password`, `code`, `mode`;
  `canSubmit` from the validator or the numeric code length; `submit()`, `resendCode()`, `toggleMode()`, `cancel()`;
  moves to `confirm` on `confirmationRequired`, back to `signIn` on `confirmedButSignInFailed`).
- Views: [./Views/EGM.md](./Views/EGM.md) - `SignInSheet` (`NavigationStack` with Close
  (`AccessibilityIdentifiers.signInClose`), three `ProviderButton`s centred in the medium detent, `.lilyFormSheet()`,
  its own `.errorPopup`, dismisses when `session.state.user` appears, cancels on disappear) and `EmailSignInView`
  (email, password and code fields with `AccessibilityIdentifiers.authEmail`/`authPassword`/`authConfirmationCode`,
  submit/resend/toggle/back buttons, grows the sheet to `.large` before focusing a field and gives `.medium` back when
  focus leaves, own back button that lowers the keyboard before the pop).
