import Foundation

nonisolated extension AppBranding.Chat {
    /// Copy of the chat's attachments: the attach menu, the strip above the composer, the pictures, videos and files in
    /// a bubble, the full-screen viewer and the player.
    enum Attachments {
        /// VoiceOver name of the "+" that opens the attach menu (its label is a glyph).
        static let attach = "Attach"
        static let photoLibrary = "Photo library"
        static let camera = "Camera"
        static let file = "File"
        /// VoiceOver name of the X on a picked picture.
        static let remove = "Remove"
        /// Under a picture whose upload failed; tapping it tries again.
        static let retryUpload = "Upload failed. Tap to retry."
        /// VoiceOver names of a picture and a video in a bubble, and what a file card is called when the sender named none.
        static let photo = "Photo"
        static let video = "Video"
        static let fileFallbackName = "File"
        /// VoiceOver hint on a file card whose bytes are not on the device yet.
        static let download = "Download"
        static let share = "Share"
        static let close = "Close"
        /// On the last tile of a gallery with more pictures than it shows: `%ld` is how many are hidden.
        static let moreFormat = "+%ld"

        static func more(_ count: Int) -> String {
            String(format: moreFormat, count)
        }
    }
}
