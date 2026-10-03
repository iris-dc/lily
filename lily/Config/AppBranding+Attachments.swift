import Foundation

nonisolated extension AppBranding.Chat {
    /// Copy of the chat's attachments: the attach menu, the strip above the composer, the pictures, videos and files in
    /// a bubble, the full-screen viewer and the player.
    enum Attachments {
        /// VoiceOver name of the "+" that opens the attach menu (its label is a glyph).
        static var attach: String { localized("Attach") }
        static var photoLibrary: String { localized("Photo library") }
        static var camera: String { localized("Camera") }
        static var file: String { localized("File") }
        /// VoiceOver name of the X on a picked picture.
        static var remove: String { localized("Remove") }
        /// Under a picture whose upload failed; tapping it tries again.
        static var retryUpload: String { localized("Upload failed. Tap to retry.") }
        /// VoiceOver names of a picture and a video in a bubble, and what a file card is called when the sender named none.
        static var photo: String { localized("Photo") }
        static var video: String { localized("Video") }
        static var fileFallbackName: String { localized("File") }
        /// VoiceOver hint on a file card whose bytes are not on the device yet.
        static var download: String { localized("Download") }
        static var share: String { localized("Share") }
        static var close: String { localized("Close") }
        /// On the last tile of a gallery with more pictures than it shows: how many are hidden.
        static func more(_ count: Int) -> String {
            localized("+\(count)")
        }
    }
}
