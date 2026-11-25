import SwiftUI

/// A section of rows under a title: the rows separated by `AvatarRowDivider`, or a quiet line when there are none.
/// A profile's shared lists and Profile's history screen share it.
struct RowsSection<Item: Identifiable, Row: View>: View {
    let title: String
    let emptyNote: String
    let items: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            SectionTitle(text: title)
            if items.isEmpty {
                SectionNote(text: emptyNote)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        row(item)
                        AvatarRowDivider()
                    }
                }
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
            }
        }
    }
}

/// A quiet secondary line at a section's text margin: "none yet", or why a load failed.
struct SectionNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, DesignTokens.Layout.screenMargin)
    }
}
