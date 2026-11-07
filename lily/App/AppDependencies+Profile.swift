import Foundation

extension AppDependencies {
    /// The display name editor; the draft starts from the store's name, loaded when Profile opened.
    func makeDisplayNameViewModel() -> DisplayNameViewModel {
        DisplayNameViewModel(store: profile, errorCenter: errorCenter, logger: logger)
    }

    /// The "About you" editor; the draft starts from the store's bio.
    func makeAboutViewModel() -> AboutViewModel {
        AboutViewModel(store: profile, errorCenter: errorCenter, logger: logger)
    }

    /// The delete-account flow over the me repository and the session's dedicated account-deleted end.
    func makeDeleteAccountViewModel() -> DeleteAccountViewModel {
        DeleteAccountViewModel(repository: meRepository, session: sessionController, errorCenter: errorCenter, logger: logger)
    }
}
