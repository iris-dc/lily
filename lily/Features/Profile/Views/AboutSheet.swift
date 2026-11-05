import SwiftUI

/// The "About you" editor: one growing field and Save in the bar, over the shared `DraftSheet`. The footer says where
/// the text shows, or that it is over the cap; an emptied field clears the bio.
struct AboutSheet: View {
    let viewModel: AboutViewModel
    let errorCenter: ErrorCenter

    private typealias Copy = AppBranding.About

    var body: some View {
        DraftSheet(viewModel: viewModel,
                   title: Copy.title,
                   submitTitle: Copy.save,
                   cancelIdentifier: AccessibilityIdentifiers.profileAboutCancel,
                   submitIdentifier: AccessibilityIdentifiers.profileAboutSave,
                   errorCenter: errorCenter) { model in
            @Bindable var model = model
            Form {
                Section {
                    TextField(Copy.placeholder, text: $model.draft.text, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(DesignTokens.Layout.aboutFieldLines)
                        .accessibilityIdentifier(AccessibilityIdentifiers.profileAboutField)
                } footer: {
                    if let hint = model.draft.hint {
                        ValidationHint(hint)
                    } else {
                        Text(Copy.footer)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .readableColumn()
        }
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    AboutSheet(viewModel: dependencies.makeAboutViewModel(), errorCenter: dependencies.errorCenter)
}
