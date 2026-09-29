import SwiftUI

/// The Home tab. Its root is the one `NavigationStack` bound to `AppNavigation.homePath`, so a push made from elsewhere
/// in the app (an invite, a group's "Open chat") lands here.
struct HomeTab: View {
    let dependencies: AppDependencies

    var body: some View {
        @Bindable var navigation = dependencies.navigation
        NavigationStack(path: $navigation.homePath) {
            HomeView(dependencies: dependencies)
        }
    }
}

#Preview {
    HomeTab(dependencies: .makeMock())
}
