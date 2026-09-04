import Foundation

/// Client-side sanity checks before credentials leave the device. Cognito remains the authority.
nonisolated enum CredentialsValidator {
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@"), at != trimmed.startIndex else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        guard let dot = domain.firstIndex(of: "."), dot != domain.startIndex else { return false }
        return dot < domain.index(before: domain.endIndex)
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= AppConfig.Auth.minimumPasswordLength
    }
}
