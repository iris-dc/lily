import SwiftUI

/// The display name editor: one field and Save in the bar, over the shared `DraftSheet` (Cancel, the popup, the close
/// once the backend answered). The footer says where the name shows, or that it is over the cap.
struct DisplayNameSheet: View {
    let viewModel: DisplayNameViewModel
    let errorCenter: ErrorCenter

    private typealias Copy = AppBranding.DisplayName

    var body: some View {
        DraftSheet(viewModel: viewModel,
                   title: Copy.title,
                   submitTitle: Copy.save,
                   cancelIdentifier: AccessibilityIdentifiers.profileNameCancel,
                   submitIdentifier: AccessibilityIdentifiers.profileNameSave,
                   errorCenter: errorCenter) { model in
            @Bindable var model = model
            Form {
                Section {
                    TextField(Copy.placeholder, text: $model.draft.text)
                        .textInputAutocapitalization(.words)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier(AccessibilityIdentifiers.profileNameField)
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
    DisplayNameSheet(viewModel: dependencies.makeDisplayNameViewModel(), errorCenter: dependencies.errorCenter)
}
