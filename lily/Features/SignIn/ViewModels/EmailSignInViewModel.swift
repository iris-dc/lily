import Foundation
import Observation

nonisolated enum EmailAuthMode: Hashable, Sendable {
    case signIn, signUp

    var title: String {
        switch self {
        case .signIn: AppBranding.signInSheetTitle
        case .signUp: AppBranding.signUpSheetTitle
        }
    }

    var submitLabel: String {
        switch self {
        case .signIn: AppBranding.signInAction
        case .signUp: AppBranding.signUpAction
        }
    }

    var toggleLabel: String {
        switch self {
        case .signIn: AppBranding.signUpPrompt
        case .signUp: "\(AppBranding.signInPrompt) \(AppBranding.signInAction)"
        }
    }

    var toggled: EmailAuthMode { self == .signIn ? .signUp : .signIn }
}

@Observable
final class EmailSignInViewModel {
    var email = ""
    var password = ""
    var mode: EmailAuthMode = .signIn
    private(set) var isSubmitting = false
    /// The in-flight submit, kept so a dismissed form can cancel it.
    private(set) var submitTask: Task<Void, Never>?

    private let session: SessionController

    init(session: SessionController) {
        self.session = session
    }

    var canSubmit: Bool {
        !isSubmitting && CredentialsValidator.isValidEmail(email) && CredentialsValidator.isValidPassword(password)
    }

    var passwordHint: String {
        AppBranding.passwordHint(minimumLength: AppConfig.Auth.minimumPasswordLength)
    }

    func toggleMode() { mode = mode.toggled }

    /// Signs in or signs up with the form's credentials. Ignored while the form is invalid or a submit is running;
    /// the keyboard's return key can reach this even though the button is disabled.
    func submit() {
        guard canSubmit else { return }
        isSubmitting = true
        submitTask = Task {
            defer { isSubmitting = false }
            await authenticate()
        }
    }

    /// Stops an in-flight submit, for example when the form goes away before the provider answers.
    func cancel() {
        submitTask?.cancel()
        submitTask = nil
    }

    private func authenticate() async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .signIn:
            await session.signIn(with: .email(EmailCredentials(email: trimmedEmail, password: password)))
        case .signUp:
            await session.signUp(email: trimmedEmail, password: password)
        }
    }
}
