import Foundation

/// What a gallery needs of a stored attachment or a draft to lay it out: its kind, for the media/files partition, and,
/// for a single picture, its shape. `AttachmentColumn` draws both over this, so the unsent bubble and the stored one it
/// becomes follow one rule.
nonisolated protocol GalleryItem {
    var kind: AttachmentKind { get }
    /// Width over height when known; square otherwise.
    var aspectRatio: CGFloat? { get }
}
