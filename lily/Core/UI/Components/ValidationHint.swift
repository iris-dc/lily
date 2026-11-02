import SwiftUI

/// A field's issue under it ("Enter a valid email", "Draws are not allowed"): the words in the secondary label colour,
/// the accent on the glyph beside them, since the accent reads at about 3:1 as small text over the aurora and the mark
/// carries the meaning instead. The font is the caller's (a form footer's footnote, a caption). One accessibility
/// element, the words; the glyph says nothing, as the popup's does.
struct ValidationHint: View {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var body: some View {
        Label {
            // `Color.secondary`, not the hierarchical `.secondary`: a form footer is already drawn at that level, and a
            // hierarchical style inside it steps down once more (measured 2.64:1, tertiary grey).
            Text(message)
                .foregroundStyle(Color.secondary)
        } icon: {
            Image(systemName: DesignTokens.Symbols.error)
                .foregroundStyle(Color.lilyAccent)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    ContentScreen {
        Form {
            Section {
                TextField("Email", text: .constant("marta@"))
            } footer: {
                ValidationHint("Enter a valid email address")
            }
        }
        .scrollContentBackground(.hidden)
    }
}
