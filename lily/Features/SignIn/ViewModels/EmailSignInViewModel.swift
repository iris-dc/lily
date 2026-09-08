import Foundation
import Observation

nonisolated enum EmailAuthMode: Hashable, Sendable {
    case signIn, signUp

    var title: String {
        switch self {
        case .signIn: "Welcome back"
        case .signUp: "Create your account"
        }
    }

    var submitLabel: String {
        switch self {
        case .signIn: "Sign in"
        case .signUp: "Sign up"
        }
    }

    var toggleLabel: String {
        switch self {
        case .signIn: "New here? Create an account"
        case .signUp: "Already have an account? Sign in"
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

    private let session: SessionController

    init(session: SessionController) {
        self.session = session
    }

    var canSubmit: Bool {
        !isSubmitting && CredentialsValidator.isValidEmail(email) && CredentialsValidator.isValidPassword(password)
    }

    var passwordHint: String {
        "At least \(AppConfig.Auth.minimumPasswordLength) characters"
    }

    func toggleMode() { mode = mode.toggled }

    /// Returns `true` when the user is now signed in and the sheet can close.
    func submit() async -> Bool {
        guard canSubmit else { return false }
        isSubmitting = true
        defer { isSubmitting = false }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        switch mode {
        case .signIn:
            return await session.signIn(with: .email(EmailCredentials(email: trimmedEmail, password: password)))
        case .signUp:
            return await session.signUp(email: trimmedEmail, password: password)
        }
    }
}
