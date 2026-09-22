import Foundation
import Observation

nonisolated enum EmailAuthMode: Hashable, Sendable {
    case signIn, signUp
    /// Entering the emailed code after a sign-up, or after a sign-in refused as unconfirmed.
    case confirm

    var title: String {
        switch self {
        case .signIn: AppBranding.signInSheetTitle
        case .signUp: AppBranding.signUpSheetTitle
        case .confirm: AppBranding.confirmEmailTitle
        }
    }

    var submitLabel: String {
        switch self {
        case .signIn: AppBranding.signInAction
        case .signUp: AppBranding.signUpAction
        case .confirm: AppBranding.confirmAction
        }
    }

    var toggleLabel: String {
        switch self {
        case .signIn: AppBranding.signUpPrompt
        case .signUp: "\(AppBranding.signInPrompt) \(AppBranding.signInAction)"
        case .confirm: AppBranding.backToSignInAction
        }
    }

    var toggled: EmailAuthMode { self == .signIn ? .signUp : .signIn }
}

@Observable
final class EmailSignInViewModel {
    var email = ""
    var password = ""
    var code = ""
    var mode: EmailAuthMode = .signIn
    private(set) var isSubmitting = false
    private(set) var isResending = false
    /// The in-flight submit or resend, kept so a dismissed form can cancel it.
    private(set) var submitTask: Task<Void, Never>?

    private let session: SessionController

    init(session: SessionController) {
        self.session = session
    }

    var isBusy: Bool { isSubmitting || isResending }

    var canSubmit: Bool {
        guard !isBusy else { return false }
        switch mode {
        case .signIn, .signUp: return CredentialsValidator.isValidEmail(email) && CredentialsValidator.isValidPassword(password)
        case .confirm: return isCodeComplete
        }
    }

    var subtitle: String {
        mode == .confirm ? AppBranding.confirmEmailSubtitle(email: trimmedEmail) : AppBranding.emailSignInSubtitle
    }

    var passwordHint: String {
        AppBranding.passwordHint(minimumLength: AppConfig.Auth.minimumPasswordLength)
    }

    /// Sign in <-> sign up; from the code step, back to sign in with the code dropped.
    func toggleMode() {
        code = ""
        mode = mode.toggled
    }

    /// Signs in, signs up or confirms with the form's fields. Ignored while the form is invalid or a call is running;
    /// the keyboard's return key can reach this even though the button is disabled.
    func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        submitTask = Task {
            defer { isSubmitting = false }
            await authenticate()
        }
    }

    func resendCode() {
        guard !isBusy, mode == .confirm else { return }
        isResending = true
        submitTask = Task {
            defer { isResending = false }
            await session.resendConfirmationCode(email: trimmedEmail)
        }
    }

    /// Stops an in-flight call, for example when the form goes away before the provider answers.
    func cancel() {
        submitTask?.cancel()
        submitTask = nil
    }

    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isCodeComplete: Bool {
        code.count == AppConfig.Cognito.confirmationCodeLength && code.allSatisfy(\.isNumber)
    }

    private func authenticate() async {
        let credentials = EmailCredentials(email: trimmedEmail, password: password)
        switch mode {
        case .signIn:
            enterConfirmationIfNeeded(await session.signIn(withEmail: credentials))
        case .signUp:
            enterConfirmationIfNeeded(await session.signUp(email: credentials.email, password: credentials.password))
        case .confirm:
            await session.confirmSignUp(email: credentials.email, code: code, password: credentials.password)
        }
    }

    private func enterConfirmationIfNeeded(_ result: EmailAuthResult) {
        if result == .confirmationRequired { mode = .confirm }
    }
}
