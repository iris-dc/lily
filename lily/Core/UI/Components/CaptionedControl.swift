import SwiftUI

/// A caption over a control that draws no label of its own inside a `Form` or a panel: segmented pickers and chip rows
/// ("Allowed | Not allowed" alone said nothing about draws).
struct CaptionedControl<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title).font(LilyTheme.Fonts.caption).foregroundStyle(.secondary)
            content()
        }
    }
}
