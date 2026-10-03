import Foundation

nonisolated extension AppBranding.Events {
    /// The edit sheet, opened from the Edit button the host sees on their game's detail; the form is the create form.
    enum Edit {
        /// The detail's toolbar button.
        static var action: String { localized("Edit") }
        static var title: String { localized("Edit game") }
        static var save: String { localized("Save") }
    }
}
