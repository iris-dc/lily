import Foundation

/// Width over height from two optional pixel hints, for a gallery to size a single picture; nil when either is unknown
/// or not positive. The one rule behind `Attachment.aspectRatio` and `AttachmentDraft.aspectRatio`.
nonisolated enum AspectRatio {
    static func of(width: Int?, height: Int?) -> CGFloat? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return CGFloat(width) / CGFloat(height)
    }
}
