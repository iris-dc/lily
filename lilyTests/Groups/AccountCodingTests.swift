import Foundation
import Testing
@testable import lily

/// `GET /api/me` with and without `attachmentsEnabled`: present on a current backend, read as off when an older one
/// leaves it out.
struct AccountCodingTests {
    @Test func attachmentsEnabledIsReadAndDefaultsToOff() throws {
        let current = try ContractSamples.decode(Account.self, from: ContractSamples.me)
        #expect(current.attachmentsEnabled)

        let older = try ContractSamples.decode(Account.self, from: ContractSamples.minimalMe)
        #expect(!older.attachmentsEnabled && !older.isOperator && older.termsVersion == 1)
    }

    @Test func theFlagSurvivesARoundTrip() throws {
        let account = Account.fixture(attachmentsEnabled: true)
        let decoded = try APIJSONCoding.makeDecoder().decode(Account.self, from: APIJSONCoding.makeEncoder().encode(account))

        #expect(decoded == account)
        #expect(!Account.fixture().attachmentsEnabled, "the fixture's default is off, like an older backend")
    }
}
