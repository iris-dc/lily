import SwiftUI

/// A caption over a control that draws no label of its own inside a `Form` or a panel, such as a segmented `Picker` or
/// a chip row: "Allowed | Not allowed" alone says nothing about draws.
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
