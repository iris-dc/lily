import Foundation

/// The email sign-up and its confirmation step. Sign-in itself and the session state stay in the main file; the slot
/// (`authenticating`), `performSignIn` and `report` are shared with it.
extension SessionController {
    /// Holds the authentication slot for the whole sign-up, so a provider tap cannot interleave with it.
    @discardableResult
    func signUp(email: String, password: String) async -> EmailAuthResult {
        await authenticating(.email, busy: .failed) {
            do {
                switch try await authService.signUp(email: email, password: password) {
                case .signedUp:
                    logger.info(.auth, "Sign-up succeeded")
                    return await performSignIn(with: .email(EmailCredentials(email: email, password: password)))
                case .confirmationRequired:
                    logger.info(.auth, "Sign-up needs email confirmation")
                    return .confirmationRequired
                }
            } catch {
                return report(error, during: "Sign-up")
            }
        }
    }

    /// Confirms the emailed code, then signs in with the password the form kept. `.confirmedButSignInFailed` when the
    /// pool accepted the code and only that sign-in did not land (it reports itself, so one popup): the form returns to
    /// sign-in instead of offering a second confirm, which Cognito refuses as "not authorized".
    @discardableResult
    func confirmSignUp(email: String, code: String, password: String) async -> ConfirmOutcome {
        await authenticating(.email, busy: .failed) {
            do {
                try await authService.confirmSignUp(email: email, code: code)
                logger.info(.auth, "Email confirmed")
            } catch {
                report(error, during: "Confirmation")
                return .failed
            }
            let signIn = await performSignIn(with: .email(EmailCredentials(email: email, password: password)))
            guard signIn == .signedIn else {
                logger.info(.auth, "Email confirmed, the sign-in after it did not land: the form returns to sign-in")
                return .confirmedButSignInFailed
            }
            return .signedIn
        }
    }

    @discardableResult
    func resendConfirmationCode(email: String) async -> Bool {
        do {
            try await authService.resendConfirmationCode(email: email)
            logger.info(.auth, "Confirmation code resent")
            return true
        } catch {
            report(error, during: "Resend")
            return false
        }
    }
}
