import SwiftUI

extension EnvironmentValues {
    /// The namespace a transcript's picture and video tiles share with the viewer that zooms out of them; `nil` where no
    /// viewer opens (a preview), and the tiles are then plain.
    @Entry var attachmentZoom: Namespace.ID?
}

extension View {
    /// Marks a tile as the place the viewer zooms out of for `attachmentID`, and back into when it is closed or dragged
    /// away.
    func attachmentZoomSource(_ attachmentID: String) -> some View {
        modifier(AttachmentZoomSource(attachmentID: attachmentID))
    }

    /// The system's zoom transition out of the tile of `attachmentID`: the viewer opens from the tile and closes back
    /// into it. Plain where there is no namespace.
    func zoomsFromAttachment(_ attachmentID: String, in namespace: Namespace.ID?) -> some View {
        modifier(AttachmentZoomDestination(attachmentID: attachmentID, namespace: namespace))
    }
}

private struct AttachmentZoomSource: ViewModifier {
    let attachmentID: String
    @Environment(\.attachmentZoom) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: attachmentID, in: namespace)
        } else {
            content
        }
    }
}

private struct AttachmentZoomDestination: ViewModifier {
    let attachmentID: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.navigationTransition(.zoom(sourceID: attachmentID, in: namespace))
        } else {
            content
        }
    }
}
