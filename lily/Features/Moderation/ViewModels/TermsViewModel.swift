import Foundation
import Observation

/// The terms sheet's state: shown while a signed-in caller owes the current terms (the account loaded without them
/// accepted, or a write answered `TERMS_REQUIRED`), closed by an acceptance the backend recorded or by signing out.
@Observable
final class TermsViewModel {
    private(set) var isAccepting = false

    private let me: MeStore
    private let identity: any IdentityProvider
    private let logger: any Logging
    private let signOutAction: () async -> Void

    init(me: MeStore, identity: any IdentityProvider, logger: any Logging, signOut: @escaping () async -> Void) {
        self.me = me
        self.identity = identity
        self.logger = logger
        self.signOutAction = signOut
    }

    /// A guest is never asked: `MeStore.termsOutdated` can be set without an account.
    var isPresented: Bool { identity.currentUserID != nil && me.needsTerms }
    var termsURL: URL { AppConfig.Moderation.termsURL }
    var privacyURL: URL { AppConfig.Moderation.privacyURL }
    var supportURL: URL { AppConfig.Moderation.supportURL }

    /// Drops a second tap while one accept is in flight. `MeStore.acceptTerms` reports a failure to the popup and logs
    /// the success, so this only brackets `isAccepting`.
    func accept() async {
        guard !isAccepting else { return }
        isAccepting = true
        defer { isAccepting = false }
        _ = await me.acceptTerms()
    }

    /// The one way out without agreeing; the session's observers clear the account and the sheet follows.
    func signOut() async {
        logger.info(.groups, "Terms declined: signing out")
        await signOutAction()
    }
}
