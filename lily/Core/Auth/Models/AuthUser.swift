import Foundation

nonisolated struct AuthUser: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let email: String?

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    /// "jane.doe@example.com" becomes "Jane Doe": the pool stores no name, so the local part is the best first guess.
    static func displayName(fromEmail email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? email
        return local.split(whereSeparator: { $0 == "." || $0 == "_" })
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}
