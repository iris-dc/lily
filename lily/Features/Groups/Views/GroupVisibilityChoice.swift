import SwiftUI

/// The public/private segmented choice of a group, and of a standalone tournament (which passes its own title and
/// identifier); the footer explaining the choice stays with the caller.
struct GroupVisibilityChoice: View {
    @Binding var visibility: GroupVisibility
    var title: String = AppBranding.Groups.Create.visibility
    var identifier: String = AccessibilityIdentifiers.createGroupVisibility

    var body: some View {
        Picker(title, selection: $visibility) {
            ForEach(GroupVisibility.allCases, id: \.self) { visibility in
                Label(visibility.displayName, systemImage: visibility.symbolName).tag(visibility)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier(identifier)
    }
}
