import Foundation

nonisolated extension AppBranding {
    /// The shared shape of the legal reading screens (Settings → Privacy policy / Terms of use): one catalog key per
    /// heading and paragraph, so each screen is data-driven and the copy translates like everything else.
    enum Legal {
        /// One heading with its paragraphs; the title text is its identity (one key per text, the catalog's rule).
        nonisolated struct Section: Identifiable, Sendable {
            let title: String
            let paragraphs: [Paragraph]
            var id: String { title }
        }

        /// One paragraph, opened by a short bold lead ("Your account.") where the served page uses one.
        nonisolated struct Paragraph: Identifiable, Sendable {
            var lead: String?
            let body: String
            var id: String { body }
        }

        /// The heading both documents end on; one declaration, the catalog's one-key-one-declaration rule.
        static var changesTitle: String { localized("Changes") }
    }
}
