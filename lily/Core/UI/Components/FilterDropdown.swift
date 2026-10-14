import SwiftUI

/// Toolbar button that drops a panel of criteria down from itself as a popover (kept a popover on iPhone too, so it
/// reads as a dropdown rather than a sheet). The glyph fills while `isActive`; the panel closes itself through the
/// `dismiss` it is handed.
struct FilterDropdownButton<Panel: View>: View {
    let title: String
    let isActive: Bool
    let identifier: String
    var onPresentedChange: ((Bool) -> Void)?
    @ViewBuilder let panel: (_ dismiss: @escaping () -> Void) -> Panel
    @State private var isPresented = false

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(title, systemImage: isActive ? DesignTokens.Symbols.filterActive : DesignTokens.Symbols.filter)
        }
        .accessibilityIdentifier(identifier)
        // The filled glyph is the only visual cue that the list is narrowed; VoiceOver needs it as a value.
        .accessibilityValue(isActive ? Copy.activeValue : Copy.inactiveValue)
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            panel { isPresented = false }
                .presentationCompactAdaptation(.popover)
        }
        // One panel session is one interaction, whether it ends with Done or a tap outside.
        .onChange(of: isPresented) { onPresentedChange?(isPresented) }
    }
}

/// The dropdown's panel: a title row with an optional accessory and Done over the criteria, at the panel width, on
/// clear glass. `scrolls` wraps the column in a scroll view for a panel taller than the screen allows.
struct DropdownPanel<Accessory: View, Content: View>: View {
    let title: String
    var scrolls = false
    @ViewBuilder let accessory: () -> Accessory
    let onDone: () -> Void
    @ViewBuilder let content: () -> Content

    private typealias Copy = AppBranding.Events.Filter

    var body: some View {
        Group {
            if scrolls {
                ScrollView { column }
            } else {
                column
            }
        }
        .frame(width: DesignTokens.Layout.filterPanelWidth)
        .presentationBackground(.clear)
        .tint(Color.lilyAccent)
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack {
                Text(title).font(LilyTheme.Fonts.cardTitle)
                Spacer()
                accessory()
                Button(Copy.done, action: onDone)
                    .lilyProminentButton(sizing: .fitted, controlSize: .small)
            }
            content()
        }
        .padding(DesignTokens.Spacing.lg)
    }
}

extension DropdownPanel where Accessory == EmptyView {
    init(title: String, scrolls: Bool = false, onDone: @escaping () -> Void, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, scrolls: scrolls, accessory: { EmptyView() }, onDone: onDone, content: content)
    }
}
