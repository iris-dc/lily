import SwiftUI

extension EnvironmentValues {
    /// The width the transcript's rows may share: the part of the list inside the window's horizontal safe area
    /// (`UsableWidth`), which on an iPad is the Chats split view's detail column. `nil` until the transcript measured
    /// itself.
    @Entry var transcriptWidth: CGFloat?
}

/// A frame of `fraction` of the transcript's width, aligned to `alignment`. Falls back to `containerRelativeFrame`
/// until the width is measured; that frame is the scroll view's container, which runs under the iPad's floating Chats
/// sidebar, so rows sized from it overflow the visible column (see `UsableWidth`).
private struct TranscriptFraction: ViewModifier {
    let fraction: CGFloat
    let alignment: Alignment
    @Environment(\.transcriptWidth) private var transcriptWidth

    func body(content: Content) -> some View {
        if let transcriptWidth {
            content.frame(width: transcriptWidth * fraction, alignment: alignment)
        } else {
            content.containerRelativeFrame(.horizontal, alignment: alignment) { length, _ in length * fraction }
        }
    }
}

/// Measures the transcript and publishes its usable width to the rows under it (see `UsableWidth`).
private struct TranscriptWidthMeasurer: ViewModifier {
    @Binding var width: CGFloat?
    @Environment(\.windowWidth) private var windowWidth

    func body(content: Content) -> some View {
        let windowWidth = windowWidth
        return content
            .onGeometryChange(for: CGFloat.self,
                              of: { @Sendable proxy in
                                  UsableWidth.of(leading: proxy.safeAreaInsets.leading,
                                                 trailing: proxy.safeAreaInsets.trailing,
                                                 frameInWindow: proxy.frame(in: .global),
                                                 windowWidth: windowWidth)
                              },
                              action: { width = $0 > 0 ? $0 : nil })
            .environment(\.transcriptWidth, width)
    }
}

extension View {
    /// Sizes the view to `fraction` of the transcript's width (see `\.transcriptWidth`).
    func transcriptFraction(_ fraction: CGFloat, alignment: Alignment) -> some View {
        modifier(TranscriptFraction(fraction: fraction, alignment: alignment))
    }

    /// Measures the transcript and publishes its usable width to the rows under it.
    func measuringTranscriptWidth(_ width: Binding<CGFloat?>) -> some View {
        modifier(TranscriptWidthMeasurer(width: width))
    }
}
