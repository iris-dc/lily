import Foundation

/// Client-side checks before credentials leave the device. The email rule mirrors what Laurel's `@Email` refuses
/// (whitespace, a second `@`, a local part over `AppConfig.Auth.emailLocalPartMaxLength` UTF-16 units, a domain
/// without a dot inside), so an address that passes here is never a 400 at the contact form; Cognito remains the
/// authority for sign-in.
nonisolated enum CredentialsValidator {
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmed
        guard trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return false }
        guard let at = trimmed.firstIndex(of: "@"), at != trimmed.startIndex, trimmed.lastIndex(of: "@") == at else {
            return false
        }
        guard String(trimmed[..<at]).wireLength <= AppConfig.Auth.emailLocalPartMaxLength else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        guard let dot = domain.firstIndex(of: "."), dot != domain.startIndex else { return false }
        return dot < domain.index(before: domain.endIndex)
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= AppConfig.Auth.minimumPasswordLength
    }
}
