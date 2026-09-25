import Foundation

/// Reads claims off a JWT the app already trusts (it came from Amplify), without verifying it: the realtime connection
/// schedules its reconnect from `exp`, and the backend and AppSync do the real validation.
nonisolated enum JWTClaims {
    private struct Payload: Decodable {
        let exp: Double?
    }

    private static let segmentSeparator: Character = "."
    private static let payloadIndex = 1
    private static let base64PaddingMultiple = 4

    /// When the token expires, or `nil` when it is not a JWT with an `exp` claim.
    static func expiration(of token: String) -> Date? {
        guard let payload = payloadData(of: token),
              let exp = try? JSONDecoder().decode(Payload.self, from: payload).exp else { return nil }
        return Date(timeIntervalSince1970: exp)
    }

    /// The second segment, base64url-decoded.
    private static func payloadData(of token: String) -> Data? {
        let segments = token.split(separator: segmentSeparator, omittingEmptySubsequences: false)
        guard segments.count > payloadIndex else { return nil }
        var base64 = segments[payloadIndex].replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % base64PaddingMultiple
        if remainder > 0 {
            base64 += String(repeating: "=", count: base64PaddingMultiple - remainder)
        }
        return Data(base64Encoded: base64)
    }
}
