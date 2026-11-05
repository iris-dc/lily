import Foundation

extension AppDependencies {
    var userRepository: any UserRepository { groups.repositories.users }

    /// A person's profile screen; the name in `destination` shows until the profile answers.
    func makeUserProfileViewModel(for destination: UserProfileDestination) -> UserProfileViewModel {
        UserProfileViewModel(destination: destination,
                             repository: userRepository,
                             identity: identity,
                             myGroups: myGroups,
                             reporter: groups.errorReporter,
                             logger: logger)
    }
}
