import Foundation

nonisolated struct AuthUser: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let email: String?

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
