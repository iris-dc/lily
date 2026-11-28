import SwiftUI

/// A label with a spinner beside it while a request runs. The spinner keeps a control size of its own (`.regular` by
/// default) so that a button style's larger one does not inflate it past the text height.
struct BusyLabel<Content: View>: View {
    let isBusy: Bool
    var spinnerSize: ControlSize = .regular
    /// The form sheets' submits show the wait; a one-tap action (join, message) acts without an icon (the owner's
    /// call, 2026-11-28) and only guards against a second tap.
    var showsSpinner = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            content()
            if isBusy && showsSpinner {
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

/// A button with a spinner beside its label while its request runs; disabled without an action. The caller applies
/// the button style, which also sets the width and height.
struct BusyButton<Label: View>: View {
    let isBusy: Bool
    var showsSpinner = true
    let action: (() async -> Void)?
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            Task { await action?() }
        } label: {
            BusyLabel(isBusy: isBusy, showsSpinner: showsSpinner) { label() }
        }
        .disabled(action == nil || isBusy)
    }
}

extension BusyButton where Label == Text {
    init(_ title: String, isBusy: Bool, showsSpinner: Bool = true, action: (() async -> Void)? = nil) {
        self.init(isBusy: isBusy, showsSpinner: showsSpinner, action: action) { Text(title) }
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
