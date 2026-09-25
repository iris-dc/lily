import Foundation
import Testing
@testable import lily

struct JWTClaimsTests {
    private let expiry = Date(timeIntervalSince1970: 1_800_003_600)

    @Test func readsTheExpiryOffAnUnsignedToken() {
        #expect(JWTClaims.expiration(of: JWTFixtures.token(expiringAt: expiry)) == expiry)
    }

    /// Cognito tokens are base64url without padding; every payload length must decode.
    @Test(arguments: ["a", "ab", "abc", "abcd", "abcde"])
    func decodesEveryPaddingLength(subject: String) {
        #expect(JWTClaims.expiration(of: JWTFixtures.token(expiringAt: expiry, subject: subject)) == expiry)
    }

    @Test(arguments: ["", "not-a-jwt", "a.b", "a.!!!.c", "a.\(Data("{}".utf8).base64EncodedString()).c"])
    func anythingElseIsNil(token: String) {
        #expect(JWTClaims.expiration(of: token) == nil)
    }
}
