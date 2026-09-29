import SwiftUI

/// Heading of a section inside a scrolling screen (Home's "Your groups", Explore's "Groups"), at the screen margin,
/// with an optional trailing action such as "See all".
struct SectionTitle<Trailing: View>: View {
    let text: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(LilyTheme.Fonts.sectionTitle)
            Spacer()
            trailing()
        }
        .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(text: String) {
        self.init(text: text) { EmptyView() }
    }
}

#Preview {
    ContentScreen {
        VStack {
            SectionTitle(text: "Your groups")
            SectionTitle(text: "Groups") { Button("See all") {} }
        }
    }
}
