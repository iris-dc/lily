import Foundation
import Testing
@testable import lily

/// Invite codes as typed, pasted and shown: normalised like the backend does it, then validated.
struct InviteCodeTests {
    /// The mock code must round-trip untouched, or the mock invite path could never be redeemed.
    @Test func mockCodeIsCanonical() throws {
        let code = try #require(InviteCode(AppConfig.Groups.mockInviteCode))
        #expect(code.value == AppConfig.Groups.mockInviteCode)
        #expect(InviteCode.normalize(AppConfig.Groups.mockInviteCode) == AppConfig.Groups.mockInviteCode)
        #expect(code.formatted == "KRZB-7K3M-QX9P")
    }

    @Test func normalizeStripsSeparatorsUpperCasesAndReadsLookAlikes() {
        #expect(InviteCode.normalize("krzb-7k3m-qx9p") == "KRZB7K3MQX9P")
        #expect(InviteCode.normalize(" KRZB 7K3M QX9P ") == "KRZB7K3MQX9P")
        #expect(InviteCode.normalize("IL0O") == "1100")
        #expect(InviteCode.normalize("ilo") == "110")
    }

    /// Only the alphabet's 32 symbols, exactly 12 of them; `U` is not in Crockford base32.
    @Test func validationNeedsTwelveAlphabetSymbols() {
        #expect(InviteCode("KRZB-7K3M-QX9P") != nil)
        #expect(InviteCode("krzb7k3mqx9i")?.value == "KRZB7K3MQX91")
        #expect(InviteCode("KRZB7K3MQX9") == nil, "eleven symbols")
        #expect(InviteCode("KRZB7K3MQX9PA") == nil, "thirteen symbols")
        #expect(InviteCode("KRZB7K3MQX9U") == nil, "U is not in the alphabet")
        #expect(InviteCode("KRZB7K3MQX9*") == nil)
        #expect(InviteCode("") == nil)
        #expect(!InviteCode.isValid("krzb7k3mqx9p"), "validation expects normalised input")
    }

    @Test func groupedFormatsPartialInputInFours() {
        #expect(InviteCode.grouped("").isEmpty)
        #expect(InviteCode.grouped("KRZ") == "KRZ")
        #expect(InviteCode.grouped("KRZB7") == "KRZB-7")
        #expect(InviteCode.grouped("KRZB7K3MQX9P") == "KRZB-7K3M-QX9P")
    }

    /// The code goes into a body as `{code}`, the canonical form, and nowhere else.
    @Test func payloadCarriesTheCanonicalCodeOnly() throws {
        let code = try #require(InviteCode("krzb-7k3m-qx9p"))
        let data = try APIJSONCoding.makeEncoder().encode(InviteCodePayload(code))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(json as NSDictionary == ["code": "KRZB7K3MQX9P"] as NSDictionary)
        #expect(code.id == code.value)
    }
}
