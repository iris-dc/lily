import Foundation
import Testing
@testable import lily

/// `GET /api/me` with and without `attachmentsEnabled`: present since chat wave 3, read as off when absent.
struct AccountCodingTests {
    @Test func attachmentsEnabledIsReadAndDefaultsToOff() throws {
        let current = try ContractSamples.decode(Account.self, from: ContractSamples.me)
        #expect(current.attachmentsEnabled)

        let older = try ContractSamples.decode(Account.self, from: ContractSamples.minimalMe)
        #expect(!older.attachmentsEnabled && !older.isOperator && older.termsVersion == 1)
    }

    @Test func theFlagSurvivesARoundTripAndTheTermsAcceptance() throws {
        let account = Account.fixture(attachmentsEnabled: true)
        let decoded = try APIJSONCoding.makeDecoder().decode(Account.self, from: APIJSONCoding.makeEncoder().encode(account))

        #expect(decoded == account)
        let accepted = account.acceptingTerms(TermsAcceptance(acceptedTermsVersion: 1, acceptedTermsAt: .now))
        #expect(accepted.attachmentsEnabled && accepted.termsAccepted)
        #expect(!Account.fixture().attachmentsEnabled, "the fixture's default is off, like an older backend")
    }
}
