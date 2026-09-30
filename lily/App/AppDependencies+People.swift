import Foundation

extension AppDependencies {
    var userRepository: any UserRepository { groups.userRepository }

    /// A person's profile screen; the name in `destination` shows until the profile answers.
    func makeUserProfileViewModel(for destination: UserProfileDestination) -> UserProfileViewModel {
        UserProfileViewModel(destination: destination,
                             repository: userRepository,
                             identity: identity,
                             myGroups: myGroups,
                             navigation: navigation,
                             reporter: groups.errorReporter,
                             logger: logger)
    }
}
