import SwiftUI

/// A glass card that leads somewhere: the caller's label, a trailing chevron as the cue, the whole card the tap
/// target. One init runs an action, the other pushes its value on the stack it is in; both wear `.plain`, because
/// a bare `NavigationLink` tints its label with the accent and has no row surface or full-row hit shape of its own.
struct GlassNavigationRow<Value: Hashable, Label: View>: View {
    private let trigger: Trigger
    private let identifier: String
    @ViewBuilder private let label: () -> Label

    private enum Trigger {
        case action(() -> Void)
        case push(Value)
    }

    init(value: Value, identifier: String, @ViewBuilder label: @escaping () -> Label) {
        self.init(trigger: .push(value), identifier: identifier, label: label)
    }

    private init(trigger: Trigger, identifier: String, @ViewBuilder label: @escaping () -> Label) {
        self.trigger = trigger
        self.identifier = identifier
        self.label = label
    }

    var body: some View {
        row
            .buttonStyle(.plain)
            .lilyHoverable()
            .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var row: some View {
        switch trigger {
        case .action(let action):
            Button(action: action) { card }
        case .push(let value):
            NavigationLink(value: value) { card }
        }
    }

    private var card: some View {
        GlassCard {
            HStack(spacing: DesignTokens.Spacing.md) {
                label()
                Spacer()
                Image(systemName: DesignTokens.Symbols.chevron)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension GlassNavigationRow where Value == Never {
    init(identifier: String, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.init(trigger: .action(action), identifier: identifier, label: label)
    }
}

/// The icon, title and optional line on what the row is for that the settings rows share.
struct GlassNavigationRowLabel: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(DesignTokens.Layout.settingsSubtitleLines)
                        // Inside the label a long subtitle is cut on one line unless told it may grow downwards.
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

extension GlassNavigationRow where Value == Never, Label == GlassNavigationRowLabel {
    init(title: String, subtitle: String? = nil, systemImage: String, identifier: String, action: @escaping () -> Void) {
        self.init(identifier: identifier,
                  action: action,
                  label: { GlassNavigationRowLabel(title: title, subtitle: subtitle, systemImage: systemImage) })
    }
}

extension GlassNavigationRow where Label == GlassNavigationRowLabel {
    init(title: String, subtitle: String? = nil, systemImage: String, value: Value, identifier: String) {
        self.init(value: value,
                  identifier: identifier,
                  label: { GlassNavigationRowLabel(title: title, subtitle: subtitle, systemImage: systemImage) })
    }
}

#Preview {
    NavigationStack {
        ContentScreen {
            VStack(spacing: DesignTokens.Spacing.md) {
                GlassNavigationRow(title: "Pick on the map",
                                   subtitle: "Drop a pin where you play",
                                   systemImage: DesignTokens.Symbols.pickedLocation,
                                   identifier: "preview-action") {}
                GlassNavigationRow(title: "Pick on the map",
                                   systemImage: DesignTokens.Symbols.map,
                                   value: "map",
                                   identifier: "preview-push")
            }
            .padding(DesignTokens.Layout.screenMargin)
        }
    }
}
