import SwiftUI

/// A label with a spinner beside it while a request runs. The spinner keeps a control size of its own (`.regular` by
/// default) so that a button style's larger one does not inflate it past the text height.
struct BusyLabel<Content: View>: View {
    let isBusy: Bool
    var spinnerSize: ControlSize = .regular
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            content()
            if isBusy {
                // The button's `.large` control size would inflate the spinner past the text height.
                ProgressView()
                    .controlSize(spinnerSize)
                    .accessibilityHidden(true)
            }
        }
    }
}

extension BusyLabel where Content == Text {
    init(_ title: String, isBusy: Bool, spinnerSize: ControlSize = .regular) {
        self.init(isBusy: isBusy, spinnerSize: spinnerSize) { Text(title) }
    }
}

/// Action with a spinner beside its title while the request runs. Without an action it is disabled. The caller
/// applies the button style, which also sets the full width and height (see the Buttons note in CLAUDE.md).
struct BusyButton<Label: View>: View {
    let isBusy: Bool
    let action: (() async -> Void)?
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            Task { await action?() }
        } label: {
            BusyLabel(isBusy: isBusy) { label() }
        }
        .disabled(action == nil || isBusy)
    }
}

extension BusyButton where Label == Text {
    init(_ title: String, isBusy: Bool, action: (() async -> Void)? = nil) {
        self.init(isBusy: isBusy, action: action) { Text(title) }
    }

    /// A write that answers whether it went through; `onSuccess` runs then (a sheet closing itself, for example).
    init(_ title: String, isBusy: Bool, write: @escaping () async -> Bool, onSuccess: @escaping () -> Void) {
        self.init(title, isBusy: isBusy) {
            if await write() {
                onSuccess()
            }
        }
    }
}
