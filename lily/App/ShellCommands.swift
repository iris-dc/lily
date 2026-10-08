import SwiftUI

/// The scene's menu commands, which a hardware keyboard reaches as shortcuts (and iPadOS lists in its menu bar):
/// ⌘1 to ⌘4 select the tabs in bar order, ⌘N, ⌘⇧N and ⌘⇧T ask Explore for a new game, group or tournament (a guest
/// is offered sign-in there, as from the "+" button). The commands only touch `AppNavigation`; the views do the rest.
/// Nothing happens on the launch or landing screens: a create parked there would pop its sheet the moment the user
/// entered the app.
struct ShellCommands: Commands {
    let dependencies: AppDependencies

    private var navigation: AppNavigation { dependencies.navigation }

    /// Whether the shell (the tabs) is on screen: a guest or a signed-in user, never the landing.
    private var isInShell: Bool {
        switch dependencies.sessionController.state {
        case .guest, .signedIn: true
        case .loading, .signedOut: false
        }
    }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button(AppBranding.Events.Create.title) { inShell { $0.requestCreate(.game) } }
                .keyboardShortcut("n", modifiers: .command)
            if AppConfig.FeatureFlags.groups {
                Button(AppBranding.Groups.Create.title) { inShell { $0.requestCreate(.group) } }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            if AppConfig.FeatureFlags.tournaments {
                Button(AppBranding.Tournaments.Create.title) { inShell { $0.requestCreate(.tournament) } }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
        CommandGroup(after: .toolbar) {
            ForEach(Array(AppTab.shown.enumerated()), id: \.element) { index, tab in
                Button(tab.title) { inShell { $0.selectedTab = tab } }
                    .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
            }
        }
    }

    private func inShell(_ action: (AppNavigation) -> Void) {
        guard isInShell else { return }
        action(navigation)
    }
}
