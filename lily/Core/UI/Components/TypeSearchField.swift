import SwiftUI

/// The type pickers' small search field: the magnifier, the shared placeholder and the glass capsule, one look for
/// the wizard's grid and the edit form's compact chips. The caller owns the query and names the field for its tests.
struct TypeSearchField: View {
    @Binding var query: String
    let identifier: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: DesignTokens.Symbols.search)
                .foregroundStyle(.secondary)
            TextField(AppBranding.Create.typeSearch, text: $query)
                .autocorrectionDisabled()
                .accessibilityIdentifier(identifier)
        }
        .lilyField()
    }
}

#Preview {
    @Previewable @State var query = ""
    ContentScreen {
        TypeSearchField(query: $query, identifier: "")
            .padding()
    }
}
