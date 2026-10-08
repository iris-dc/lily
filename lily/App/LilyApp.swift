import SwiftUI

@main
struct LilyApp: App {
    @UIApplicationDelegateAdaptor(LilyAppDelegate.self) private var appDelegate
    private let dependencies = AppDependencies.makeDefault()

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
                .tint(Color.lilyAccent)
        }
        .commands { ShellCommands(dependencies: dependencies) }
    }
}
