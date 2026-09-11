import Foundation
import Observation

/// Drives the sign-in sheet: provider buttons plus the push into the email form.
/// Owns the in-flight sign-in so a dismissed sheet can cancel it instead of signing the user in behind its back.
@Observable
final class SignInViewModel {
    var isEmailFormPresented = false
    private(set) var signInTask: Task<Void, Never>?
    private let session: SessionController

    init(session: SessionController) {
        self.session = session
    }

    var authenticatingProvider: AuthProvider.Kind? { session.authenticatingProvider }
    var isBusy: Bool { authenticatingProvider != nil }

    func signInWithApple() { signIn(with: .apple) }
    func signInWithGoogle() { signIn(with: .google) }
    func presentEmailForm() { isEmailFormPresented = true }

    /// Stops an in-flight sign-in, for example when the sheet goes away before the provider answers.
    func cancel() {
        signInTask?.cancel()
        signInTask = nil
    }

    private func signIn(with provider: AuthProvider) {
        signInTask?.cancel()
        signInTask = Task { await session.signIn(with: provider) }
    }
}
