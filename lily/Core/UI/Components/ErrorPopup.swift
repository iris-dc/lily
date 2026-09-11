import SwiftUI

/// The single user-facing error surface. Mount it at the root and on the root of every sheet with
/// `.errorPopup(errorCenter)`: a sheet is drawn above the root, so the root copy alone would sit behind it.
/// Only the mount that appeared last draws, so the error never shows twice.
struct ErrorPopupView: View {
    let presented: PresentedError
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            Image(systemName: DesignTokens.Symbols.error)
                .font(.title3)
                .foregroundStyle(Color.lilyAccent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(presented.message.title).font(.headline)
                Text(presented.message.body).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) {
                Image(systemName: DesignTokens.Symbols.dismiss)
                    .font(.footnote.weight(.bold))
                    .frame(width: DesignTokens.Layout.controlHeight, height: DesignTokens.Layout.controlHeight)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppBranding.dismissAction)
        }
        .padding(DesignTokens.Spacing.lg)
        .glassEffect(.regular.tint(Color.lilyAccent.opacity(DesignTokens.Opacity.glassTint)),
                     in: .rect(cornerRadius: DesignTokens.Radius.card))
        .frame(maxWidth: DesignTokens.Layout.popupMaxWidth)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .accessibilityElement(children: .combine)
    }
}

private struct ErrorPopupModifier: ViewModifier {
    let errorCenter: ErrorCenter
    @State private var presenter = UUID()

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if errorCenter.isTopPresenter(presenter), let presented = errorCenter.current {
                ErrorPopupView(presented: presented) { errorCenter.dismiss(presented.id) }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .gesture(dismissSwipe(for: presented))
                    .task(id: presented.id) {
                        try? await Task.sleep(for: AppConfig.ErrorPopup.autoDismissDelay)
                        guard !Task.isCancelled else { return }
                        errorCenter.dismiss(presented.id)
                    }
            }
        }
        .animation(.spring(duration: DesignTokens.Duration.normal), value: errorCenter.current?.id)
        .onAppear { errorCenter.beginPresenting(presenter) }
        .onDisappear { errorCenter.endPresenting(presenter) }
    }

    private func dismissSwipe(for presented: PresentedError) -> some Gesture {
        DragGesture(minimumDistance: DesignTokens.Layout.swipeDismissDistance).onEnded { value in
            if value.translation.height < 0 { errorCenter.dismiss(presented.id) }
        }
    }
}

extension View {
    func errorPopup(_ errorCenter: ErrorCenter) -> some View {
        modifier(ErrorPopupModifier(errorCenter: errorCenter))
    }
}
