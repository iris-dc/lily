import Foundation
import Observation

/// Drives the sign-in sheet: provider buttons plus the push into the email form.
@Observable
final class SignInViewModel {
    var isEmailFormPresented = false
    private let session: SessionController

    init(session: SessionController) {
        self.session = session
    }

    var authenticatingProvider: AuthProvider.Kind? { session.authenticatingProvider }
    var isBusy: Bool { authenticatingProvider != nil }

    func signInWithApple() async { await session.signIn(with: .apple) }
    func signInWithGoogle() async { await session.signIn(with: .google) }
    func presentEmailForm() { isEmailFormPresented = true }
}
