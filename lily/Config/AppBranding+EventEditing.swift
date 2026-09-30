import Foundation

nonisolated extension AppBranding.Events {
    /// The edit sheet, opened from the Edit button the host sees on their game's detail; the form is the create form.
    enum Edit {
        /// The detail's toolbar button.
        static let action = "Edit"
        static let title = "Edit game"
        static let save = "Save"
    }
}
