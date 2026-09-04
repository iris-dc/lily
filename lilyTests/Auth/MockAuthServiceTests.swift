import Foundation
import Testing
@testable import lily

@MainActor
struct MockAuthServiceTests {
    private func makeService(_ behavior: MockAuthBehavior = .succeed) -> (MockAuthService, InMemorySessionStore) {
        let store = InMemorySessionStore()
        return (MockAuthService(behavior: behavior, delay: .zero, store: store), store)
    }

    @Test(arguments: [AuthProvider.apple, .google, .email(TestFixtures.credentials)])
    func signInReturnsDeterministicUserAndPersists(provider: AuthProvider) async throws {
        let (service, store) = makeService()

        let session = try await service.signIn(with: provider)

        #expect(session.user == MockUsers.user(for: provider))
        #expect(store.stored == .signedIn(session))
    }

    @Test func emailUserGetsReadableDisplayName() {
        let user = MockUsers.user(for: .email(TestFixtures.credentials))
        #expect(user.displayName == "Jane Doe")
        #expect(user.email == TestFixtures.credentials.email)
    }

    @Test func restoreReturnsPersistedSession() async throws {
        let (service, store) = makeService()
        store.stored = .signedIn(TestFixtures.session)

        #expect(try await service.restoreSession() == TestFixtures.session)
    }

    @Test func restoreIgnoresGuestChoice() async throws {
        let (service, store) = makeService()
        store.stored = .guest

        #expect(try await service.restoreSession() == nil)
    }

    @Test func failureBehaviorThrowsConfiguredError() async {
        let (service, _) = makeService(.fail(.network))

        await #expect(throws: AppError.network) {
            try await service.signIn(with: .apple)
        }
    }

    @Test func signUpRejectsWeakCredentials() async {
        let (service, _) = makeService()

        await #expect(throws: AppError.invalidCredentials) {
            try await service.signUp(email: "bad", password: "short")
        }
    }

    @Test func signOutClearsStore() async throws {
        let (service, store) = makeService()
        store.stored = .signedIn(TestFixtures.session)

        try await service.signOut()

        #expect(store.stored == nil)
    }
}

@MainActor
struct MockUsersTests {
    @Test func emailUserIDNeverEmbedsTheEmail() {
        let user = MockUsers.user(for: .email(TestFixtures.credentials))
        #expect(!user.id.localizedCaseInsensitiveContains(TestFixtures.credentials.email))
        #expect(!user.id.localizedCaseInsensitiveContains("jane"))
    }

    @Test func emailUserIDIsStableAndCaseInsensitive() {
        let lower = MockUsers.user(for: .email(EmailCredentials(email: "a@b.co", password: "p")))
        let upper = MockUsers.user(for: .email(EmailCredentials(email: "A@B.CO", password: "q")))
        let other = MockUsers.user(for: .email(EmailCredentials(email: "c@b.co", password: "p")))
        #expect(lower.id == upper.id)
        #expect(lower.id != other.id)
    }
}
