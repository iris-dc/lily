import SwiftUI
import UIKit

/// Which notifications reach this device, pushed from Settings: the system permission's state first (ask, or the way
/// to the system settings once declined), then one switch per push kind once granted. A mute silences the banner
/// alone; the item still lands in the app's inbox, as the footnote says.
struct NotificationsScreen: View {
    @State private var viewModel: NotificationsViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private typealias Copy = AppBranding.Notifications

    init(viewModel: NotificationsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ContentScreen {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
                    content
                }
                .padding(.horizontal, DesignTokens.Layout.screenMargin)
                .padding(.vertical, DesignTokens.Spacing.xl)
                .readableColumn()
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .navigationTitle(Copy.title)
        .task { await viewModel.refresh() }
        // Back from the system settings: the permission may have flipped there.
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            Task { await viewModel.refresh() }
        }
    }

    @ViewBuilder private var content: some View {
        switch viewModel.authorization {
        case nil:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.lg)
        case .notDetermined:
            note(Copy.notDeterminedMessage)
            Button(Copy.enableAction) { Task { await viewModel.enable() } }
                .lilyProminentButton()
                .accessibilityIdentifier(AccessibilityIdentifiers.notificationsEnable)
        case .denied:
            note(Copy.deniedMessage)
            Button(Copy.openSettingsAction) { openSystemSettings() }
                .lilyGlassButton(sizing: .fitted, controlSize: .regular, labelColor: .lilyInk)
                .accessibilityIdentifier(AccessibilityIdentifiers.notificationsOpenSettings)
        case .authorized:
            ForEach(NotificationKind.allCases, id: \.self) { kind in
                toggleRow(kind)
            }
        }
    }

    /// One switch per push kind; the identifier rides on the switch itself, so a test finds it, not the card.
    private func toggleRow(_ kind: NotificationKind) -> some View {
        GlassCard {
            Toggle(isOn: binding(for: kind)) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(Copy.title(for: kind))
                    Text(Copy.caption(for: kind))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color.lilyAccent)
            .accessibilityIdentifier(AccessibilityIdentifiers.notificationToggle(kind))
        }
    }

    private func binding(for kind: NotificationKind) -> Binding<Bool> {
        Binding(get: { viewModel.isEnabled(kind) }, set: { viewModel.set(kind, enabled: $0) })
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    let dependencies = AppDependencies.makeMock()
    NavigationStack {
        NotificationsScreen(viewModel: dependencies.makeNotificationsViewModel())
    }
}
