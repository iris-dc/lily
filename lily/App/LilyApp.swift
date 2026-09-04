import SwiftUI

@main
struct LilyApp: App {
    private let dependencies = AppDependencies.makeDefault()

    var body: some Scene {
        WindowGroup {
            AppRootView(dependencies: dependencies)
                .tint(Color.lilyAccent)
        }
    }
}
