import Foundation

extension AppDependencies {
    /// The terms sheet over the account store; "Sign out" goes through the session controller, whose observers clear
    /// the account and so close the sheet. Lives here because `AppDependencies.swift` is at its file-length limit.
    func makeTermsViewModel() -> TermsViewModel {
        TermsViewModel(me: me, identity: identity, logger: logger) { [sessionController] in
            await sessionController.signOut()
        }
    }
}
