import Foundation
import Observation

@Observable
final class WelcomeViewModel {
    var isEmailSheetPresented = false
    private let session: SessionController

    init(session: SessionController) {
        self.session = session
    }

    var authenticatingProvider: AuthProvider.Kind? { session.authenticatingProvider }
    var isBusy: Bool { authenticatingProvider != nil }

    func signInWithApple() async { await session.signIn(with: .apple) }
    func signInWithGoogle() async { await session.signIn(with: .google) }
    func presentEmailSignIn() { isEmailSheetPresented = true }
    func continueAsGuest() { session.continueAsGuest() }
}
