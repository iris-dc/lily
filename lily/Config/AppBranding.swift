import Foundation

/// Everything that identifies the product to the user. Change here, and every screen follows.
nonisolated enum AppBranding {
    static let name = "lily"

    /// Landing headline, one line per element. The last line is highlighted in the accent color.
    static let headline = ["Pick a sport.", "Find your people.", "Play tonight."]
    static let subheadline = "Real games near you, organised by people like you. Join one or start your own."

    static let landingPrimaryAction = "Find a game near you"
    static let signInPrompt = "Already have an account?"
    static let signInAction = "Sign in"

    static let signInSheetTitle = "Welcome back"
    static let signInSheetSubtitle = "Sign in to create games, join and chat."

    /// Copy templates for sign-in buttons: `%@` is the provider's display name.
    static let signInButtonFormat = "Continue with %@"

    static func signInButtonTitle(for providerName: String) -> String {
        String(format: signInButtonFormat, providerName)
    }
}
