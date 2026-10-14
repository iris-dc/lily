import Foundation

extension AppDependencies {
    /// The shell's restore and per-user sync over the stores and coordinators built here; `AppRootView` only ties it
    /// to the scene phase and the session.
    func makeShellSync() -> ShellSync {
        ShellSync(session: sessionController,
                  navigation: navigation,
                  me: me,
                  realtime: realtime,
                  myGroups: myGroups,
                  inbox: inbox,
                  blocks: blocks,
                  push: pushCoordinator)
    }
}
