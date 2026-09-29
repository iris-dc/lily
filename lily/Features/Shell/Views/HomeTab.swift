import SwiftUI

/// The Home tab. Its root is the one `NavigationStack` bound to `AppNavigation.homePath`, so a group opened from
/// elsewhere in the app (a founded group, a Home row) lands here.
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
