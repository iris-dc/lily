import QuickLook
import SwiftUI

/// Opens a message's file the way Files does: the system's QuickLook sheet with its own title, Done and Share. `url`
/// is the preview copy `AttachmentLoader.previewFile` made (named after the file, so QuickLook knows what it is), set
/// to open the sheet and cleared by the sheet closing; the copy is removed once the sheet is gone. SwiftUI's own
/// presentation is used rather than a `QLPreviewController` representable, because a preview controller hosted
/// inside another presentation shows no Done button.
struct QuickLookPreview: ViewModifier {
    @Binding var url: URL?

    func body(content: Content) -> some View {
        content
            .quickLookPreview($url)
            .onChange(of: url) { previous, current in
                if current == nil, let previous { PreviewFiles.remove(previous) }
            }
    }
}

extension View {
    func attachmentQuickLook(_ url: Binding<URL?>) -> some View {
        modifier(QuickLookPreview(url: url))
    }
}
