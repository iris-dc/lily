import Foundation

extension AppDependencies {
    /// The terms sheet over the account store; its "Sign out" goes through the session controller, whose observers
    /// clear the account and so close the sheet.
    func makeTermsViewModel() -> TermsViewModel {
        TermsViewModel(me: me, identity: identity, logger: logger) { [sessionController] in
            await sessionController.signOut()
        }
    }
}
