import Foundation

extension AppDependencies {
    var inboxRepository: any InboxRepository { groups.repositories.inbox }
    var inbox: InboxStore { groups.inbox }

    /// The inbox screen over the shared store; an accepted invite's group goes into Mine and its chat opens, an accepted
    /// tournament or event invite reloads its lists and opens the detail.
    func makeInboxViewModel() -> InboxViewModel {
        InboxViewModel(store: inbox,
                       repository: inboxRepository,
                       opener: eventOpener,
                       myGroups: myGroups,
                       groupRepository: groupRepository,
                       tournamentChanges: tournamentChanges,
                       eventChanges: eventChanges,
                       navigation: navigation,
                       errorCenter: errorCenter,
                       logger: logger)
    }
}
